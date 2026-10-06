// Compact native artwork browser. A transient modal GTK dialog stays above Takt
// on Wayland/X11; unlike an unparented desktop-portal chooser it floats with it.
#pragma once
#include <algorithm>
#include <string>
#include <vector>
#include "artwork_preview.h"

struct ArtworkPicker {
  GtkWidget* dialog;
  GtkWidget* list;
  GtkWidget* location;
  GtkWidget* preview;
  GtkWidget* caption;
  bool completed = false;
  std::string error_text;
  FlMethodCall* call;
  std::string directory;
};

static void artwork_preview(ArtworkPicker* picker) {
  if (picker->completed) return;
  gtk_image_clear(GTK_IMAGE(picker->preview));
  gtk_label_set_text(GTK_LABEL(picker->caption), "");
  gtk_dialog_set_response_sensitive(GTK_DIALOG(picker->dialog), GTK_RESPONSE_ACCEPT, FALSE);
  GtkListBoxRow* row = gtk_list_box_get_selected_row(GTK_LIST_BOX(picker->list));
  const char* path = row ? static_cast<const char*>(g_object_get_data(G_OBJECT(row), "path")) : nullptr;
  if (!path || g_file_test(path, G_FILE_TEST_IS_DIR)) return;
  auto image = load_artwork_preview(path, 420, 420);
  if (!image.pixbuf) {gtk_label_set_text(GTK_LABEL(picker->caption), picker->error_text.c_str()); return;}
  gtk_image_set_from_pixbuf(GTK_IMAGE(picker->preview), image.pixbuf);
  g_object_unref(image.pixbuf);
  g_autofree gchar* name = g_path_get_basename(path);
  const std::string caption = std::string(name) + "\n" + std::to_string(image.width) + " × " + std::to_string(image.height);
  gtk_label_set_text(GTK_LABEL(picker->caption), caption.c_str());
  gtk_dialog_set_response_sensitive(GTK_DIALOG(picker->dialog), GTK_RESPONSE_ACCEPT, TRUE);
}

static void artwork_list(ArtworkPicker* picker) {
  gtk_image_clear(GTK_IMAGE(picker->preview));
  gtk_label_set_text(GTK_LABEL(picker->caption), "");
  gtk_dialog_set_response_sensitive(GTK_DIALOG(picker->dialog), GTK_RESPONSE_ACCEPT, FALSE);
  GList* children = gtk_container_get_children(GTK_CONTAINER(picker->list));
  for (GList* child = children; child; child = child->next)
    gtk_widget_destroy(GTK_WIDGET(child->data));
  g_list_free(children);
  gtk_entry_set_text(GTK_ENTRY(picker->location), picker->directory.c_str());
  std::vector<std::pair<bool, std::string>> files;
  GDir* directory = g_dir_open(picker->directory.c_str(), 0, nullptr);
  if (directory) {
    const gchar* name;
    while ((name = g_dir_read_name(directory))) {
      if (name[0] == '.') continue;
      const std::string path = picker->directory + "/" + name;
      const bool folder = g_file_test(path.c_str(), G_FILE_TEST_IS_DIR);
      // Let GdkPixbuf inspect supported image types, rather than trust extensions.
      if (folder || gdk_pixbuf_get_file_info(path.c_str(), nullptr, nullptr))
        files.emplace_back(folder, name);
    }
    g_dir_close(directory);
  }
  std::sort(files.begin(), files.end(), [](const auto& a, const auto& b) {
    return a.first != b.first ? a.first > b.first : a.second < b.second;
  });
  for (const auto& file : files) {
    GtkWidget* row = gtk_list_box_row_new();
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget* icon = gtk_image_new_from_icon_name(
        file.first ? "folder" : "image-x-generic", GTK_ICON_SIZE_MENU);
    GtkWidget* label = gtk_label_new(file.second.c_str());
    gtk_label_set_xalign(GTK_LABEL(label), 0);
    gtk_label_set_ellipsize(GTK_LABEL(label), PANGO_ELLIPSIZE_END);
    gtk_container_set_border_width(GTK_CONTAINER(box), 6);
    gtk_box_pack_start(GTK_BOX(box), icon, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), label, TRUE, TRUE, 0);
    gtk_container_add(GTK_CONTAINER(row), box);
    g_object_set_data_full(G_OBJECT(row), "path",
        g_strdup((picker->directory + "/" + file.second).c_str()), g_free);
    gtk_container_add(GTK_CONTAINER(picker->list), row);
  }
  gtk_widget_show_all(picker->list);
}

static void artwork_response(GtkDialog*, gint response, gpointer data) {
  auto* picker = static_cast<ArtworkPicker*>(data);
  g_autoptr(FlValue) result = nullptr;
  if (response == GTK_RESPONSE_ACCEPT) {
    GtkListBoxRow* row = gtk_list_box_get_selected_row(GTK_LIST_BOX(picker->list));
    const char* path = row ? static_cast<const char*>(
        g_object_get_data(G_OBJECT(row), "path")) : nullptr;
    if (!path) return;
    if (g_file_test(path, G_FILE_TEST_IS_DIR)) {
      picker->directory = path;
      artwork_list(picker);
      return;
    }
    auto image = load_artwork_preview(path, 32, 32);
    if (!image.pixbuf) {artwork_preview(picker);return;}
    g_object_unref(image.pixbuf);
    result = fl_value_new_string(path);
  }
  if (picker->completed) return;
  picker->completed = true;
  fl_method_call_respond_success(picker->call, result, nullptr);
  gtk_widget_destroy(picker->dialog);
}

static void artwork_pick(FlMethodChannel*, FlMethodCall* call, gpointer parent) {
  if (g_strcmp0(fl_method_call_get_name(call), "pick") != 0) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  FlValue* args = fl_method_call_get_args(call);
  auto text = [args](const char* key, const char* fallback) {
    FlValue* value = args ? fl_value_lookup_string(args, key) : nullptr;
    return value && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
        ? fl_value_get_string(value) : fallback;
  };
  auto* picker = new ArtworkPicker{};
  picker->call = FL_METHOD_CALL(g_object_ref(call));
  picker->directory = g_get_user_special_dir(G_USER_DIRECTORY_PICTURES)
      ? g_get_user_special_dir(G_USER_DIRECTORY_PICTURES) : g_get_home_dir();
  if (!g_file_test(picker->directory.c_str(), G_FILE_TEST_IS_DIR))
    picker->directory = g_get_home_dir();
  picker->dialog = gtk_dialog_new_with_buttons(text("title", "Choose artwork"),
      GTK_WINDOW(parent), static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT),
      text("cancel", "Cancel"), GTK_RESPONSE_CANCEL,
      text("open", "Open"), GTK_RESPONSE_ACCEPT, nullptr);
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(parent));
  GdkWindow* parent_window = gtk_widget_get_window(GTK_WIDGET(parent));
  GdkMonitor* monitor = parent_window ? gdk_display_get_monitor_at_window(display, parent_window) : gdk_display_get_primary_monitor(display);
  GdkRectangle work = {0, 0, 800, 600};
  if (monitor) gdk_monitor_get_workarea(monitor, &work);
  gtk_window_set_default_size(GTK_WINDOW(picker->dialog), std::min(800, work.width), std::min(600, work.height));
  gtk_window_set_resizable(GTK_WINDOW(picker->dialog), TRUE);
  picker->error_text = text("error", "Cannot preview this image");
  gtk_widget_set_name(picker->dialog, "takt-artwork-picker");
  GtkCssProvider* css = gtk_css_provider_new();
  const bool dark = g_strcmp0(text("theme", "light"), "dark") == 0;
  const std::string rules = dark
      ? "#takt-artwork-picker, #takt-artwork-picker box, #takt-artwork-picker list {background-color: #252627; color: #eeeeee;}"
      : "#takt-artwork-picker, #takt-artwork-picker box, #takt-artwork-picker list {background-color: #f4f4f4; color: #202020;}";
  const std::string style = rules + " #takt-artwork-picker button, #takt-artwork-picker entry {border-radius: 16px; padding: 8px;}";
  gtk_css_provider_load_from_data(css, style.c_str(), -1, nullptr);
  gtk_style_context_add_provider_for_screen(gtk_widget_get_screen(picker->dialog), GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_set_data_full(G_OBJECT(picker->dialog), "takt-css", css, g_object_unref);
  gtk_window_set_position(GTK_WINDOW(picker->dialog), GTK_WIN_POS_CENTER_ON_PARENT);
  GtkWidget* content = gtk_dialog_get_content_area(GTK_DIALOG(picker->dialog));
  gtk_container_set_border_width(GTK_CONTAINER(content), 10);
  GtkWidget* navigation = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
  GtkWidget* up = gtk_button_new_from_icon_name("go-up", GTK_ICON_SIZE_MENU);
  picker->location = gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(navigation), up, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(navigation), picker->location, TRUE, TRUE, 0);
  gtk_box_pack_start(GTK_BOX(content), navigation, FALSE, FALSE, 0);
  GtkWidget* scroll = gtk_scrolled_window_new(nullptr, nullptr);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  picker->list = gtk_list_box_new();
  gtk_list_box_set_selection_mode(GTK_LIST_BOX(picker->list), GTK_SELECTION_SINGLE);
  gtk_container_add(GTK_CONTAINER(scroll), picker->list);
  GtkWidget* panes = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
  gtk_paned_pack1(GTK_PANED(panes), scroll, TRUE, FALSE);
  GtkWidget* preview_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
  picker->preview = gtk_image_new();
  picker->caption = gtk_label_new("");
  gtk_label_set_line_wrap(GTK_LABEL(picker->caption), TRUE);
  gtk_label_set_max_width_chars(GTK_LABEL(picker->caption), 36);
  gtk_box_pack_start(GTK_BOX(preview_box), picker->preview, TRUE, TRUE, 8);
  gtk_box_pack_start(GTK_BOX(preview_box), picker->caption, FALSE, FALSE, 8);
  gtk_paned_pack2(GTK_PANED(panes), preview_box, TRUE, FALSE);
  gtk_paned_set_position(GTK_PANED(panes), 300);
  gtk_box_pack_start(GTK_BOX(content), panes, TRUE, TRUE, 8);
  g_signal_connect(picker->list, "row-selected", G_CALLBACK(+[](GtkListBox*, GtkListBoxRow*, gpointer data) {artwork_preview(static_cast<ArtworkPicker*>(data));}), picker);
  g_signal_connect(up, "clicked", G_CALLBACK(+[](GtkButton*, gpointer data) {
    auto* p = static_cast<ArtworkPicker*>(data);
    g_autofree gchar* path = g_path_get_dirname(p->directory.c_str());
    p->directory = path;
    artwork_list(p);
  }), picker);
  g_signal_connect(picker->location, "activate", G_CALLBACK(+[](GtkEntry* entry, gpointer data) {
    auto* p = static_cast<ArtworkPicker*>(data);
    const char* path = gtk_entry_get_text(entry);
    if (g_file_test(path, G_FILE_TEST_IS_DIR)) {
      p->directory = path;
      artwork_list(p);
    }
  }), picker);
  g_signal_connect(picker->list, "row-activated", G_CALLBACK(+[](GtkListBox*, GtkListBoxRow* row, gpointer data) {
    auto* p = static_cast<ArtworkPicker*>(data);
    const char* path = static_cast<const char*>(g_object_get_data(G_OBJECT(row), "path"));
    if (path && g_file_test(path, G_FILE_TEST_IS_DIR)) {p->directory = path;artwork_list(p);} else {artwork_preview(p);}
  }), picker);
  g_signal_connect(picker->dialog, "response", G_CALLBACK(artwork_response), picker);
  g_signal_connect(picker->dialog, "destroy", G_CALLBACK(+[](GtkWidget* dialog, gpointer data) {
    auto* p = static_cast<ArtworkPicker*>(data);
    if (!p->completed) fl_method_call_respond_success(p->call, nullptr, nullptr);
    GtkCssProvider* css = static_cast<GtkCssProvider*>(g_object_get_data(G_OBJECT(dialog), "takt-css"));
    if (css) gtk_style_context_remove_provider_for_screen(gtk_widget_get_screen(dialog), GTK_STYLE_PROVIDER(css));
    g_object_unref(p->call); delete p;
  }), picker);
  artwork_list(picker);
  gtk_widget_show_all(picker->dialog);
  gtk_window_present(GTK_WINDOW(picker->dialog));
}
