using GLib;


public class ClientTask : Task {
  public weak Server server { get; construct; }

  private Pid pid;

  public ClientTask(uint64 id, Server server) {
    Object(id: id, server: server);
  }

  public override void start() {
    try {
      Process.spawn_async(null,
                          {"emacsclient",
                            "--socket-name=" + this.server.name,
                            "--create-frame",
                            "--no-wait",
                            null},
                          null,
                          SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                          null,
                          out this.pid);

      ChildWatch.add(this.pid, on_exit);

    } catch (Error e) {
      message("Failed to run emacs client '%s': %s", this.server.name, e.message);
    }
  }

  private void on_exit(Pid pid, int status) {
    debug("process exited: %i", status);
    Process.close_pid(this.pid);
    this.finished();
  }
}


public class EvalTask : Task {
  public weak Server server { get; construct; }
  public string cmd { get; construct; }

  private Pid pid;
  private IOChannel? stderr_channel = null;
  private IOChannel? stdout_channel = null;
  private string result;

  public EvalTask(uint64 id, Server server, string cmd) {
    Object(id: id, server: server, cmd: cmd);
  }

  public override void start() {
    int stdin_fd;
    int stdout_fd;
    int stderr_fd;

    try {
      Process.spawn_async_with_pipes(null,
                                     {"emacsclient",
                                       "--socket-name=" + this.server.name,
                                       "--eval", this.cmd,
                                       null},
                                     null,
                                     SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                     null,
                                     out this.pid,
                                     out stdin_fd,
                                     out stdout_fd,
                                     out stderr_fd);

      Posix.close(stdin_fd);

      ChildWatch.add(this.pid, this.on_exit);

      this.stderr_channel = new IOChannel.unix_new(stderr_fd);
      this.stdout_channel = new IOChannel.unix_new(stdout_fd);
      this.stderr_channel.set_close_on_unref(true);
      this.stdout_channel.set_close_on_unref(true);
      this.stdout_channel.add_watch(IOCondition.IN|IOCondition.HUP, on_stderr);
      this.stdout_channel.add_watch(IOCondition.IN|IOCondition.HUP, on_stdout);

    } catch (Error e) {
      message("Failed to run emacs client '%s': %s", this.server.name, e.message);
    }
  }

  private bool on_stderr(IOChannel io, IOCondition condition) {
    debug("on_stderr");

    if ((condition & IOCondition.HUP) == IOCondition.HUP) {
      debug("Write end of pipe died!\n");
      return false;
    }

    string result;
    size_t length;
    try {
      io.read_to_end(out result, out length);
    }
    catch(IOChannelError e) {
      message("Error reading: %s\n", e.message);
    }
    catch(ConvertError e) {
      message("Error reading: %s\n", e.message);
    }
    debug(result);
    return true;
  }

  private bool on_stdout(IOChannel io, IOCondition condition) {
    debug("on_stdout");

    if ((condition & IOCondition.HUP) == IOCondition.HUP) {
      debug("Write end of pipe died!\n");
      return false;
    }

    string result;
    size_t length;
    try {
      io.read_to_end(out result, out length);
    }
    catch(IOChannelError e) {
      message("Error reading: %s\n", e.message);
    }
    catch(ConvertError e) {
      message("Error reading: %s\n", e.message);
    }
    debug(result);
    return true;
  }

  private void on_exit(Pid pid, int status) {
    debug("process exited: %i", status);
    Process.close_pid(this.pid);
    this.finished();
  }
}
