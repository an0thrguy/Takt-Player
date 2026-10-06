#pragma once
#include <gdk-pixbuf/gdk-pixbuf.h>
// Scaled decoding bounds memory for the preview; caller owns the returned pixbuf.
struct ArtworkPreview { GdkPixbuf* pixbuf = nullptr; int width = 0; int height = 0; };
static ArtworkPreview load_artwork_preview(const char* path, int max_width, int max_height) {
 ArtworkPreview result;
 if (!gdk_pixbuf_get_file_info(path, &result.width, &result.height)) return result;
 GError* error = nullptr;
 result.pixbuf = gdk_pixbuf_new_from_file_at_scale(path, max_width, max_height, TRUE, &error);
 g_clear_error(&error);
 return result;
}
