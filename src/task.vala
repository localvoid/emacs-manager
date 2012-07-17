using GLib;

public abstract class Task : Object {
  public uint64 id { get; construct; }
  public signal void finished();

  public Task(uint64 id) {
    Object(id: id);
  }

  public abstract void start();
}
