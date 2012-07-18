namespace SessionManager {

public errordomain ConnectionError {
  CONNECTION_FAILED,
  CLIENT_REGISTRATION_FAILED
}

public const string DBUS_NAME = "org.gnome.SessionManager";
public const string DBUS_PATH = "/org/gnome/SessionManager";

[DBus (name = "org.gnome.SessionManager")]
private interface SessionManager : Object {
  public abstract void register_client(string app_id,
                                       string client_startup_id,
                                       out ObjectPath client_id) throws IOError;
  public abstract void unregister_client(ObjectPath client_id) throws IOError;
}

[DBus (name = "org.gnome.SessionManager.ClientPrivate")]
private interface ClientPrivate : Object {
  public abstract void end_session_response(bool is_ok, string reason) throws IOError;
  public signal void query_end_session(uint flags);
  public signal void end_session(uint flags);
  public signal void cancel_end_session();
  public signal void stop();
}

}