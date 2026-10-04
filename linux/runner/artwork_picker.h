// Compact native artwork browser. A transient modal GTK dialog stays above Takt
// on Wayland/X11; unlike an unparented desktop-portal chooser it floats with it.
#pragma once
#include <algorithm>
#include <string>
#include <vector>

struct ArtworkPicker {
  GtkWidget* dialog;
  GtkWidget* list;
  GtkWidget* location;
  FlMethodCall* call;
  std::string directory;
};

static void artwork_list(ArtworkPicker* picker) {
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
    result = fl_value_new_string(path);
  }
  fl_method_call_respond_success(picker->call, result, nullptr);
  g_object_unref(picker->call);
  gtk_widget_destroy(picker->dialog);
  delete picker;
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
  gtk_window_set_default_size(GTK_WINDOW(picker->dialog), 400, 400);
  gtk_window_set_resizable(GTK_WINDOW(picker->dialog), FALSE);
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
  gtk_box_pack_start(GTK_BOX(content), scroll, TRUE, TRUE, 8);
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
  g_signal_connect(picker->list, "row-activated", G_CALLBACK(+[](GtkListBox*, GtkListBoxRow*, gpointer data) {
    auto* p = static_cast<ArtworkPicker*>(data);
    gtk_dialog_response(GTK_DIALOG(p->dialog), GTK_RESPONSE_ACCEPT);
  }), picker);
  g_signal_connect(picker->dialog, "response", G_CALLBACK(artwork_response), picker);
  artwork_list(picker);
  gtk_widget_show_all(picker->dialog);
  gtk_window_present(GTK_WINDOW(picker->dialog));
}
