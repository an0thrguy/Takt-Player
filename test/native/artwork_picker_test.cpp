#include <cassert>
#include <string>
#include <gtk/gtk.h>
typedef GObject FlMethodCall;
typedef void FlMethodChannel;
#define FL_METHOD_CALL(value) (value)
struct FlValue {std::string text;};
static void fl_value_free(FlValue* v){delete v;}
G_DEFINE_AUTOPTR_CLEANUP_FUNC(FlValue, fl_value_free)
enum {FL_VALUE_TYPE_STRING};
static int responses=0;static std::string result;
static FlValue* fl_method_call_get_args(FlMethodCall*){return nullptr;}
static const char* fl_method_call_get_name(FlMethodCall*){return "pick";}
static FlValue* fl_value_lookup_string(FlValue*,const char*){return nullptr;}
static int fl_value_get_type(FlValue*){return FL_VALUE_TYPE_STRING;}
static const char* fl_value_get_string(FlValue* v){return v->text.c_str();}
static FlValue* fl_value_new_string(const char* text){return new FlValue{text};}
static void fl_method_call_respond_not_implemented(FlMethodCall*,void*){}
static void fl_method_call_respond_success(FlMethodCall*,FlValue* value,void*){responses++;result=value?value->text:"";}
#include "../../linux/runner/artwork_picker.h"
static GtkWidget* find_widget(GtkWidget* root,GType type){
 if(G_TYPE_CHECK_INSTANCE_TYPE(root,type))return root;
 if(GTK_IS_CONTAINER(root)){GList* children=gtk_container_get_children(GTK_CONTAINER(root));for(GList* c=children;c;c=c->next){auto found=find_widget(GTK_WIDGET(c->data),type);if(found){g_list_free(children);return found;}}g_list_free(children);}return nullptr;
}
int main(int argc,char**argv){
 gtk_init(&argc,&argv);
 auto* parent=gtk_window_new(GTK_WINDOW_TOPLEVEL);gtk_widget_show(parent);
 auto* call=G_OBJECT(g_object_new(G_TYPE_OBJECT,nullptr));
 artwork_pick(nullptr,call,parent);
 GList* windows=gtk_window_list_toplevels();GtkWidget* dialog=nullptr;
 for(GList* w=windows;w;w=w->next)if(GTK_IS_DIALOG(w->data))dialog=GTK_WIDGET(w->data);g_list_free(windows);
 assert(dialog);assert(gtk_window_get_transient_for(GTK_WINDOW(dialog))==GTK_WINDOW(parent));assert(gtk_window_get_resizable(GTK_WINDOW(dialog)));
 auto* entry=find_widget(dialog,GTK_TYPE_ENTRY);auto* list=find_widget(dialog,GTK_TYPE_LIST_BOX);
 gtk_entry_set_text(GTK_ENTRY(entry),"/tmp/takt-picker-fixtures");g_signal_emit_by_name(entry,"activate");
 auto* row=gtk_list_box_get_row_at_index(GTK_LIST_BOX(list),0);assert(row);
 gtk_list_box_select_row(GTK_LIST_BOX(list),row);
 assert(gtk_widget_get_sensitive(gtk_dialog_get_widget_for_response(GTK_DIALOG(dialog),GTK_RESPONSE_ACCEPT)));
 g_signal_emit_by_name(list,"row-activated",row);assert(responses==0);
 gtk_dialog_response(GTK_DIALOG(dialog),GTK_RESPONSE_ACCEPT);assert(responses==1);assert(result=="/tmp/takt-picker-fixtures/image.png");
 artwork_pick(nullptr,call,parent);gtk_widget_destroy(parent);assert(responses==2);assert(result.empty());
 g_object_unref(call);
}
