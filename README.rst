===============
 Emacs Manager
===============

Installation
------------

Packages
^^^^^^^^

- Fedora 64bit - https://github.com/downloads/localvoid/emacs-manager/emacs-manager-0.1.0-1.x86_64.rpm
- Fedora 32bit - https://github.com/downloads/localvoid/emacs-manager/emacs-manager-0.1.0-1.i686.rpm

Compile from sources
^^^^^^^^^^^^^^^^^^^^

::

   ./waf configure
   ./waf
   ./waf install


DBus API
--------

com.localvoid.EmacsManager
^^^^^^^^^^^^^^^^^^^^^^^^^^
Methods:

- ObjectPath[] GetServers()
- int StartServer(string name)

Signals:

- ServerCreated(ObjectPath server_id)
- ServerDeleted(ObjectPath server_id)

com.localvoid.EmacsManager.Server
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Properties:

- string Name
- string State {"RUNNING", "KILLING", "ERROR"}

Methods:

- void Kill()
- void StartClient()
- void Execute(string cmd)
