using GLib;
using Gee;

bool is_valid_server_name(string name) {
  return Regex.match_simple("[a-zA-Z0-9_-]+", name);
}

[DBus (name = "com.localvoid.EmacsManager.Error")]
public errordomain EmacsManagerError {
  SERVER_EXISTS,
  INVALID_SERVER_NAME
}

[DBus (name = "com.localvoid.EmacsManager")]
public class EmacsManager : Object {
  public signal void server_created(ObjectPath server_id);
  public signal void server_deleted(ObjectPath server_id);

  static const string OBJECT_PATH = "/com/localvoid/EmacsManager";

  [DBus (visible = false)]
  public string sockets_path { private get; construct; }

  private DBusConnection? dbus_connection;
  private DirectoryMonitor? sockets_monitor = null;

  private LinkedList<Task>? tasks = null;
  private HashMap<string, Server>? servers = null;

  private uint64 last_server_id = 0;
  private uint64 last_task_id = 0;

  public EmacsManager(string sockets_path) {
    Object(sockets_path: sockets_path);
  }

  construct {
    this.tasks = new LinkedList<Task>();
    this.servers = new HashMap<string, Server>();

    try {
      this.dbus_connection = Bus.get_sync(BusType.SESSION);
      this.dbus_connection.register_object(OBJECT_PATH, this);

      init_monitors();
      init_running_servers();
    } catch (IOError e) {
      error("Could not register Emacs Manager service");
    }
  }

  private void init_monitors() {
    debug("Monitoring sockets at '%s'", this.sockets_path);
    this.sockets_monitor = new DirectoryMonitor(this.sockets_path);
    this.sockets_monitor.created.connect(on_socket_created);
    this.sockets_monitor.deleted.connect(on_socket_deleted);
    this.sockets_monitor.enable();
  }

  private void init_running_servers() {
    debug("Looking up local servers at '%s'", this.sockets_path);
    var f = File.new_for_path(this.sockets_path);
    try {
      if (f.query_exists(null)) {
        var enumerator = f.enumerate_children(FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file()) != null) {
          var name = file_info.get_name();
          var s = new Server(this,
                             this.dbus_connection,
                             name);
          this.servers[name] = s;
        }
      }
    } catch (Error e) {
      warning("Init running servers: %s", e.message);
    }
  }

  public uint64 get_new_server_uid() {
    return this.last_server_id++;
  }

  public uint64 get_new_task_uid() {
    return this.last_task_id++;
  }

  private void on_socket_created(File file) {
    string name = file.get_basename();
    debug("Socket created: %s", name);

    if (this.servers.has_key(name)) {
      message("Socket created, but server with name '%s' is already registered", name);
      return;
    }
    var s = new Server(this, this.dbus_connection, name);
    this.servers[name] = s;
    this.server_created(s.object_path);
  }

  private void on_socket_deleted(File file) {
    string name = file.get_basename();
    debug("Socket deleted: %s", name);

    if (this.servers.has_key(name)) {
      var s = this.servers[name];
      s.unregister();
      this.servers.unset(name);
      this.server_deleted(s.object_path);
      return;
    }
    warning("Socket deleted, but server with name '%s' is not registered", name);
    return;
  }

  public ObjectPath[] get_servers() {
    debug("GetServers");

    ObjectPath[] result = new ObjectPath[0];
    foreach (var s in this.servers.values) {
      result += s.object_path;
    }
    return result;
  }

  public int start_server(string name) throws EmacsManagerError {
    debug("StartServer: %s", name);

    if (!is_valid_server_name(name)) {
      throw new EmacsManagerError.INVALID_SERVER_NAME(name);
    }
    if (this.servers.has_key(name)) {
      throw new EmacsManagerError.SERVER_EXISTS(name);
    }
    return this.start_task(new StartDaemonTask(get_new_task_uid(), name));
  }

  [DBus (visible = false)]
  public int start_task(Task task) {
    this.tasks.add(task);
    task.finished.connect(on_task_finished);
    task.start();
    return 1;
  }

  [DBus (visible = false)]
  public void kill_all_servers() {
    foreach (var s in this.servers.values) {
      s.kill();
    }
  }

  private void on_task_finished(Task task) {
    debug("Task finished");
    this.tasks.remove(task);
  }
}
