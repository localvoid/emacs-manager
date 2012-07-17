using GLib;

public class App : Application {
  private SessionManager.ClientService? sm_client = null;
  private EmacsManager? emacs_manager = null;
  private DBusConnection? dbus_connection = null;

  private string sockets_path = "/tmp/emacs" + ((uint32)Posix.getuid()).to_string();

  construct {
    application_id = "com.localvoid.EmacsManager";
    flags = ApplicationFlags.IS_SERVICE;
    Log.set_handler(null, LogLevelFlags.LEVEL_MASK, log_handler);
  }

  private static void log_handler(string? domain, LogLevelFlags level, string message) {
    #if DEBUG
    if (level >= LogLevelFlags.LEVEL_INFO)
      level = LogLevelFlags.LEVEL_MESSAGE;
    #endif
    Log.default_handler(domain, level, message);
  }

  protected override void startup() {
    var main_loop = new MainLoop();

    register_session_client_async();
    acquire_bus_async();

    Notify.init("Emacs Manager");

    main_loop.run();
  }

  private async void acquire_bus_async() {
    Bus.own_name(BusType.SESSION,
                 "com.localvoid.EmacsManager",
                 BusNameOwnerFlags.NONE,
                 (c) => {
                   message("Bus name acquired");
                   this.dbus_connection = c;
                   this.emacs_manager = new EmacsManager(c, this.sockets_path);
                 },
                 null,
                 null);

  }

  private async void register_session_client_async() {
    if (this.sm_client != null)
      return;

    this.sm_client = new SessionManager.ClientService(this.application_id);

    try {
      this.sm_client.register();
    } catch(SessionManager.ConnectionError e) {
      critical(e.message);
      return_if_reached();
    }

    if (this.sm_client != null) {
      // The session manager may ask us to quit the service, and so we do.
      this.sm_client.stop_service.connect(() => {
          message ("Exiting...");
          this.quit_mainloop();
        });
    }
  }

  public static int main(string[] args) {
    var app = new App();
    return app.run(args);
  }
}
