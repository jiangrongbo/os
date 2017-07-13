/*++

Copyright (c) 2017 Minoca Corp.

    This file is licensed under the terms of the GNU General Public License
    version 3. Alternative licensing terms are available. Contact
    info@minocacorp.com for details. See the LICENSE file at the root of this
    project for complete licensing information.

Module Name:

    build.ck

Abstract:

    This module contains build helper routines used by packages.

Author:

    Evan Green 30-Jun-2017

Environment:

    Chalk

--*/

//
// ------------------------------------------------------------------- Includes
//

import os;
from santa.config import config;
from santa.file import chdir, mkdir, rmtree;
from santa.lib.archive import Archive;
from spawn import ChildProcess, OPTION_SHELL, OPTION_CHECK;

//
// --------------------------------------------------------------------- Macros
//

//
// ---------------------------------------------------------------- Definitions
//

//
// ------------------------------------------------------ Data Type Definitions
//

//
// ----------------------------------------------- Internal Function Prototypes
//

//
// -------------------------------------------------------------------- Globals
//

//
// ------------------------------------------------------------------ Functions
//

function
shell (
    command
    )

/*++

Routine Description:

    This routine runs a command in a shell environment, and waits for the
    result. If the command fails, an exception is raised.

Arguments:

    command - Supplies either a string or a list to run.

Return Value:

    None. If the command fails, an exception is raised.

--*/

{

    var child = ChildProcess(command);

    child.options = OPTION_SHELL | OPTION_CHECK;
    child.launch();
    child.wait(-1);
    return;
}

function
triplet (
    arch,
    osName
    )

/*++

Routine Description:

    This routine gets the config.sub triplicate for the given architecture and
    OS.

Arguments:

    arch - Supplies the architecture.

    osName - Supplies the OS name.

Return Value:

    returns the arch-machine-os triplet on success.

    null if the OS or architecture are not recognized.

--*/

{

    var triplet;

    if (arch == "all") {
        arch = os.machine;
    }

    if (osName == "Windows") {
        if (arch == "x86_64") {
            osName = "mingw64";

        } else {
            osName = "mingw32";
        }

    } else {
        osName = osName.lower();
    }

    if ((arch == "i686") || (arch == "i586") || (arch == "x86_64")) {
        triplet = "%s-pc-%s" % [arch, osName];

    } else {
        if ((arch == "armv6") || (arch == "armv7")) {
            arch = "arm";
        }

        triplet = "%s-none-%s" % [arch, osName];
    }

    return triplet;
}

function
autoconfigure (
    build,
    arguments,
    options
    )

/*++

Routine Description:

    This routine performs the autoconf configure step.

Arguments:

    build - Supplies the build object.

    arguments - Supplies additional arguments to pass along to the configure
        script.

    options - Supplies options that control execution.

Return Value:

    None. On failure, an exception is raised.

--*/

{

    var args;
    var autoreconf;
    var configure;
    var confDir;
    var vars = build.vars;

    if (options == null) {
        options = {};
    }

    configure = options.get("configure");
    if (configure != null) {
        confDir = (os.dirname)(configure);

    } else {
        confDir = "%s/%s-%s" % [vars.srcdir, vars.name, vars.version];
        configure = "%s/configure" % confDir;
    }

    //
    // On Windows, remove the drive letter since too many things get fouled up
    // by not having / as the first character.
    //

    if (os.system == "Windows") {
        if ((configure.length() > 2) && (configure[1] == ":")) {
            configure = configure[2...-1];
        }
    }

    //
    // Perform an autoreconf unless asked not to.
    //

    if (!options.get("no_reconf")) {
        chdir(confDir);
        autoreconf = options.get("reconfigure");
        if (autoreconf == null) {
            autoreconf = "${AUTORECONF:=autoreconf}";
        }

        if (options.get("reconf_args")) {
            args = "%s %s" % [autoreconf, options.reconf_args];

        } else {
            args = "%s -fi" % autoreconf;
        }

        shell(args);
    }

    chdir(vars.builddir);
    if (arguments is List) {
        arguments = " ".join(arguments);
    }

    args = "";
    if ((vars.os != vars.buildos) || (vars.arch != vars.buildarch)) {
        if (vars.flags.get("cross") == false) {
            Core.raise(ValueError("This package cannot be cross compiled"));
        }

        args += "--build=%s --host=%s " %
                [triplet(vars.buildarch, vars.buildos),
                 triplet(vars.arch, vars.os)];
    }

    if (options.get("add_paths")) {
        args += "--prefix=/usr --sysconfdir=/etc --mandir=/usr/share/man "
                "--infodir=/usr/share/info --localstatedir=/var "
                "--sharedstatedir=/var/com";
    }

    args = " ".join([configure, args, arguments]);
    shell(args);
    return;
}

//
// --------------------------------------------------------- Internal Functions
//

