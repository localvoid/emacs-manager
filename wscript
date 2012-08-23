#!/usr/bin/env python

import os

VERSION = '0.1.1'
APPNAME = 'emacs-manager'

top = '.'
out = 'build'

def options(opt):
    opt.load('compiler_c')
    opt.load('vala')

def configure(cfg):
    cfg.load('compiler_c vala')
    cfg.check_cfg(package='glib-2.0',
                  uselib_store='GLIB',
                  atleast_version='2.24.1',
                  mandatory=1,
                  args='--cflags --libs')
    cfg.check_cfg(package='gobject-2.0',
                  uselib_store='GOBJECT',
                  atleast_version='2.24.1',
                  mandatory=1,
                  args='--cflags --libs')
    cfg.check_cfg(package='gio-2.0',
                  uselib_store='GIO',
                  atleast_version='2.24.1',
                  mandatory=1,
                  args='--cflags --libs')
    cfg.check_cfg(package='gee-0.8',
                  uselib_store='GEE',
                  mandatory=1,
                  args='--cflags --libs')
    cfg.check_cfg(package='libnotify',
                  uselib_store='NOTIFY',
                  mandatory=1,
                  args='--cflags --libs')

    cfg.env['VALAFLAGS'] += ['-g']

def build(bld):
    bld.program(
        target = 'emacs-manager',
        packages = ['gio-2.0', 'posix', 'gee-0.8', 'libnotify'],
        uselib = ['GLIB', 'GOBJECT', 'GIO', 'GEE', 'NOTIFY'],
        source = [
            'src/directory_monitor.vala',
            'src/task.vala',
            'src/start_daemon_task.vala',
            'src/client_task.vala',
            'src/emacs_manager.vala',
            'src/server.vala',
            'src/session_manager.vala',
            'src/main.vala']
        )

    bld(features = 'subst',
        source = 'data/com.localvoid.EmacsManager.service.in',
        target = 'com.localvoid.EmacsManager.service',
        BINDIR=bld.env['BINDIR'])

    bld(features = 'subst',
        source = 'data/emacs-manager.desktop.in',
        target = 'emacs-manager.desktop',
        VERSION=VERSION)

    bld.install_files(os.path.join(bld.env['PREFIX'], 'share', 'dbus-1', 'services'),
                      'com.localvoid.EmacsManager.service')
    bld.install_files(os.path.join(bld.env['PREFIX'], 'share', 'applications'),
                      'emacs-manager.desktop')
