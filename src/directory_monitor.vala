public class DirectoryMonitor : Object {
  public signal void created(File file);
  public signal void deleted(File file);

  public string path { get; construct set; }
  public bool enabled { get; private set; default = false; }
  private FileMonitor monitor;

  public DirectoryMonitor(string path) {
    Object(path: path);
  }

  public void enable() {
    if (!this.enabled) {
      var file = File.new_for_path(this.path);
      try {
        this.monitor = file.monitor_directory(FileMonitorFlags.NONE);
        this.monitor.changed.connect(on_changed);
        this.enabled = true;
      } catch (IOError e) {
        error("IOError: %s", e.message);
      }
    }
  }

  public void disable() {
    if (this.enabled) {
      this.monitor.cancel();
      this.enabled = false;
    }
  }

  private void on_changed(File file, File? other_file, FileMonitorEvent event_type) {
    switch (event_type) {
    case FileMonitorEvent.CREATED:
      this.created(file);
      break;
    case FileMonitorEvent.DELETED:
      this.deleted(file);
      break;
    }
  }
}
