#include <cassert>
#include <gtk/gtk.h>
#include <glib/gstdio.h>
#include "../../linux/runner/artwork_preview.h"
int main(){
 const char* path="/tmp/takt-preview-fixture.png";
 auto image=load_artwork_preview(path,320,320);
 assert(image.pixbuf);assert(image.width==1600&&image.height==800);
 assert(gdk_pixbuf_get_width(image.pixbuf)==320);assert(gdk_pixbuf_get_height(image.pixbuf)==160);
 g_object_unref(image.pixbuf);
 assert(!load_artwork_preview("/no/such/image.png",320,320).pixbuf);
 g_file_set_contents("/tmp/takt-preview-broken.png","broken",-1,nullptr);
 assert(!load_artwork_preview("/tmp/takt-preview-broken.png",320,320).pixbuf);
 g_remove(path);g_remove("/tmp/takt-preview-broken.png");
}
