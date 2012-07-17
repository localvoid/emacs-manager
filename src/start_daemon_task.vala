using GLib;


public class StartDaemonTask : Task {
  public string name { get; construct; }

  private Pid pid;
  private IOChannel stderr_channel;
  private string body;

  public StartDaemonTask(uint64 id, string name) {
    Object(id: id, name: name);
  }

  ~StartDaemonTask() {
    debug("StartDaemonTask Destructor");
  }

  public override void start() {
    int stdin_fd;
    int stdout_fd;
    int stderr_fd;

    try {
      var venv_path = Path.build_filename(Environment.get_home_dir(),
                                          ".emacs.d",
                                          "virtualenv",
                                          this.name + ".sh");
      var venv_file = File.new_for_path(venv_path);

      string[] argv;
      if (venv_file.query_exists(null)) {
        argv = {"bash", venv_path, "-c",
                "emacs", "--daemon=" + this.name, null};
      } else {
        argv = {"emacs", "--daemon=" + this.name, null};
      }

      Process.spawn_async_with_pipes(null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                     null,
                                     out this.pid,
                                     out stdin_fd,
                                     out stdout_fd,
                                     out stderr_fd);

      Posix.close(stdin_fd);
      Posix.close(stdout_fd);

      ChildWatch.add(this.pid, on_exit);

      this.stderr_channel = new IOChannel.unix_new(stderr_fd);
      this.stderr_channel.set_close_on_unref(true);
      this.stderr_channel.add_watch(IOCondition.IN|IOCondition.HUP, on_stderr);

    } catch (Error e) {
      message("Failed to run emacs daemon '%s': %s", this.name, e.message);
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
      this.body = result;
    }
    catch(IOChannelError e) {
      message("Error reading: %s\n", e.message);
    }
    catch(ConvertError e) {
      message("Error reading: %s\n", e.message);
    }

    return true;
  }

  private void on_exit(Pid pid, int status) {
    debug("process exited: %i", status);
    Process.close_pid(this.pid);

    try {
      if (status == 0) {
        new Notify.Notification(@"Emacs Server '$(this.name)' is started",
                                null,
                                "emacs").show();
      } else {
        new Notify.Notification(@"Emacs Server '$(this.name)' is failed to run",
                                this.body,
                                "emacs").show();
      }
    } catch (Error e) {
      message(e.message);
    }

    this.finished();
  }
}
