using GLib;

[DBus (name = "com.localvoid.EmacsManager.Server")]
public class Server : Object {
  [DBus (use_string_marshalling = true)]
  public enum State {
    RUNNING,
    KILLING,
    ERROR
  }

  [DBus (visible = false)]
  public weak EmacsManager emacs_manager { private get; construct; }
  [DBus (visible = false)]
  public weak DBusConnection dbus_connection { private get; construct; }

  public string name        { get; construct; }
  public State state        { get; private construct set; default = State.RUNNING; }

  private uint registration_id;
  [DBus (visible = false)]
  public ObjectPath? object_path;

  public Server(EmacsManager e, DBusConnection c, string name) {
    Object(emacs_manager: e, dbus_connection: c, name: name);
  }

  construct {
    debug("Server '%s' created.", this.name);
    this.object_path = new ObjectPath("/com/localvoid/EmacsManager/Server/" +
                                      this.emacs_manager.get_new_server_uid().to_string());

    try {
      debug("Registering server '%s' in dbus", this.object_path);
      this.registration_id = this.dbus_connection.register_object(this.object_path, this);
      this.notify.connect(on_property_change);
    } catch (IOError e) {
      error("Could not register server '%s' in dbus.", this.name);
    }
  }

  ~Server() {
    debug("Server '%s' destructed.", this.name);
  }

  [DBus (visible = false)]
  public void unregister() {
    this.dbus_connection.unregister_object(this.registration_id);
  }

  public void kill() {
    debug("Kill server '%s'.", this.name);
    if (this.state == State.RUNNING) {
      this.emacs_manager.start_task(new EvalTask(this.emacs_manager.get_new_task_uid(), this, "(kill-emacs)"));
      this.state = State.KILLING;
    }
  }

  public void start_client() {
    debug("Start client for server '%s'.", this.name);
    if (this.state == State.RUNNING) {
      this.emacs_manager.start_task(new ClientTask(this.emacs_manager.get_new_task_uid(), this));
    }
  }

  public void execute(string cmd) {
    debug("Executing command '%' in server '%s'.", cmd, this.name);
  }

  private void on_property_change(ParamSpec p) {
    debug("Sending property change signal: %s", p.name);

    if (p.name == "state") {
      var builder = new VariantBuilder(VariantType.ARRAY);
      var invalid_builder = new VariantBuilder(new VariantType("as"));

      Variant i = this.state;
      builder.add("{sv}", "state", i);

      try {
        this.dbus_connection.emit_signal(null,
                                         this.object_path,
                                         "org.freedesktop.DBus.Properties",
                                         "PropertiesChanged",
                                         new Variant("(sa{sv}as)",
                                                     "com.localvoid.EmacsManager.Server",
                                                     builder,
                                                     invalid_builder)
                                        );
      } catch (Error e) {
        message("%s", e.message);
      }
    }
  }
}
