using GLib;

public class App : Application {
  private SessionManager.SessionManager? session_manager = null;
  private SessionManager.ClientPrivate? session_client = null;
  private ObjectPath? session_client_id = null;

  private EmacsManager? emacs_manager = null;

  private string sockets_path = "/tmp/emacs" + ((uint32)Posix.getuid()).to_string();

  construct {
    application_id = "com.localvoid.EmacsManager";
    flags = ApplicationFlags.IS_SERVICE;
    Log.set_handler(null, LogLevelFlags.LEVEL_MASK, log_handler);
    this.startup.connect(this.on_startup);
  }

  private static void log_handler(string? domain, LogLevelFlags level, string message) {
    #if DEBUG
    if (level >= LogLevelFlags.LEVEL_INFO)
      level = LogLevelFlags.LEVEL_MESSAGE;
    #endif
    Log.default_handler(domain, level, message);
  }

  private void register_session() {
    try {
      this.session_manager = Bus.get_proxy_sync(BusType.SESSION,
                                                SessionManager.DBUS_NAME,
                                                SessionManager.DBUS_PATH);

      try {
        this.session_manager.register_client(this.application_id,
                                             "emacs-manager",
                                             out this.session_client_id);

        try {
          this.session_client = Bus.get_proxy_sync(BusType.SESSION,
                                                   SessionManager.DBUS_NAME,
                                                   this.session_client_id);
        } catch (IOError e) {
          critical("Could not get client: %s", e.message);
        }
        this.session_client.query_end_session.connect(on_query_end_session);
        this.session_client.end_session.connect(on_end_session);
        this.session_client.stop.connect(on_stop);
      } catch (IOError e) {
        critical("Could not register client: %s", e.message);
      }
    } catch (IOError e) {
      critical(e.message);
    }
  }

  private void on_query_end_session() {
    debug("Query end session");
    send_end_session_response(true);
  }

  private void on_end_session() {
    debug("End session");
    this.emacs_manager.kill_all_servers();

    send_end_session_response(true);
    release();
  }

  private void on_stop() {
    debug("Stop");

    try {
      this.session_manager.unregister_client(this.session_client_id);
    } catch (IOError e) {
      critical(e.message);
    }
  }

  private void send_end_session_response(bool is_okay, string reason = "") {
    try {
      debug("Sending is_okay = %s to session manager", is_okay.to_string());
      this.session_client.end_session_response(is_okay, reason);
    } catch (IOError e) {
      warning("Couldn't reply to session manager: %s", e.message);
    }
  }

  private void on_startup() {
    if (!get_is_remote()) {
      register_session();
      Notify.init("Emacs Manager");

      this.emacs_manager = new EmacsManager(this.sockets_path);
      hold();
    }
  }

  public static int main(string[] args) {
    var app = new App();
    return app.run(args);
  }
}
