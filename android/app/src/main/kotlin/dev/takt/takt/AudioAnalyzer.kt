package dev.takt.takt

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.*

// Independent file decoding avoids microphone capture and keeps FFT off Flutter's UI thread.
class AudioAnalyzer(private val context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val ui = Handler(Looper.getMainLooper())
    @Volatile private var token = 0
    @Volatile var active = true
    @Volatile var positionMs = 0L
    @Volatile private var sink: EventChannel.EventSink? = null
    init { EventChannel(messenger, "takt/spectrum").setStreamHandler(this) }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null; cancel() }
    fun cancel() { token++ }
    fun load(uri: String, generation: Int, startMs: Long = 0) {
        positionMs = startMs
        val current = ++token
        worker.execute { decode(uri, current, generation, startMs) }
    }
    private fun decode(uri: String, current: Int, generation: Int, startMs: Long) {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(context, Uri.parse(uri), null)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return
            extractor.selectTrack(track)
            if (startMs > 0) extractor.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            val input = extractor.getTrackFormat(track)
            input.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            codec = MediaCodec.createDecoderByType(input.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(input, null, null, 0); codec.start()
            var rate = input.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = input.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var encoding = AudioFormat.ENCODING_PCM_16BIT
            val ring = DoubleArray(2048)
            var write = 0
            var total = 0L
            var index = 0
            var firstBuffer = true
            var batchStart = 0
            val batch = ArrayList<List<Double>>()
            var inputDone = false
            var outputDone = false
            val info = MediaCodec.BufferInfo()
            fun flush() {
                if (batch.isEmpty()) return
                val event = mapOf("generation" to generation, "index" to batchStart, "frames" to ArrayList(batch))
                batch.clear()
                ui.post { if (token == current) sink?.success(event) }
            }
            while (!outputDone && current == token) {
                while ((!active || index * 50L > positionMs + 8000) && current == token) Thread.sleep(50)
                if (current != token) break
                if (!inputDone) {
                    val slot = codec.dequeueInputBuffer(10000)
                    if (slot >= 0) {
                        val buffer = codec.getInputBuffer(slot)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) { codec.queueInputBuffer(slot, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputDone = true }
                        else { codec.queueInputBuffer(slot, 0, size, extractor.sampleTime, 0); extractor.advance() }
                    }
                }
                val slot = codec.dequeueOutputBuffer(info, 10000)
                if (slot == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val output = codec.outputFormat
                    rate = output.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = output.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    encoding = if (output.containsKey(MediaFormat.KEY_PCM_ENCODING)) output.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                } else if (slot >= 0) {
                    if (firstBuffer && info.size > 0) {
                        firstBuffer = false
                        total = info.presentationTimeUs.coerceAtLeast(0) * rate / 1000000
                        index = (info.presentationTimeUs.coerceAtLeast(0) / 50000).toInt()
                    }
                    codec.getOutputBuffer(slot)?.let { buffer ->
                        buffer.order(ByteOrder.LITTLE_ENDIAN)
                        buffer.position(info.offset); buffer.limit(info.offset + info.size)
                        val bytes = if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
                        while (buffer.remaining() >= channels * bytes) {
                            var sample = 0.0
                            repeat(channels) { sample += if (bytes == 4) buffer.float.toDouble() else buffer.short / 32768.0 }
                            ring[write] = sample / channels; write = (write + 1) % ring.size; total++
                            if (total >= ((index + 1L) * rate / 20)) {
                                if (batch.isEmpty()) batchStart = index
                                batch.add(spectrum(DoubleArray(ring.size) { ring[(write + it) % ring.size] }, rate))
                                index++
                                if (batch.size >= 4) flush()
                            }
                        }
                    }
                    outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    codec.releaseOutputBuffer(slot, false)
                }
            }
            flush()
        } catch (_: Exception) {
            // Unsupported platform analysis codecs leave a quiet line; libmpv playback is independent.
        } finally {
            try { codec?.stop() } catch (_: Exception) {}
            codec?.release(); extractor.release()
        }
    }

    private fun spectrum(samples: DoubleArray, rate: Int): List<Double> {
        val n = samples.size
        val mean = samples.average()
        val real = DoubleArray(n) { (samples[it] - mean) * (.5 - .5 * cos(2 * PI * it / (n - 1))) }
        val imag = DoubleArray(n)
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) { val v = real[i]; real[i] = real[j]; real[j] = v }
        }
        var length = 2
        while (length <= n) {
            val wr = cos(-2 * PI / length); val wi = sin(-2 * PI / length)
            for (start in 0 until n step length) {
                var r = 1.0; var im = 0.0
                for (offset in 0 until length / 2) {
                    val a = start + offset; val b = a + length / 2
                    val br = real[b] * r - imag[b] * im; val bi = real[b] * im + imag[b] * r
                    real[b] = real[a] - br; imag[b] = imag[a] - bi
                    real[a] += br; imag[a] += bi
                    val next = r * wr - im * wi; im = r * wi + im * wr; r = next
                }
            }
            length = length shl 1
        }
        return List(24) { band ->
            val low = 50 * 200.0.pow(band / 24.0)
            val high = 50 * 200.0.pow((band + 1) / 24.0)
            val first = max(1, floor(low * n / rate).toInt()).coerceAtMost(n / 2 - 1)
            val last = min(n / 2 - 1, max(first, ceil(high * n / rate).toInt() - 1))
            var energy = 0.0
            for (bin in first..last) energy += real[bin] * real[bin] + imag[bin] * imag[bin]
            (sqrt(energy) * 4 / n).let { if (it < .0001) 0.0 else it }
        }
    }
}
