"""Runs a Python module (pip, SCons) with Python's WMI queries switched off.

Python 3.12's platform module asks Windows Management Instrumentation for the OS version and the
processor; on this PC WMI hangs, so pip and SCons hang at start. Without WMI, platform falls back
to sys.getwindowsversion() and the PROCESSOR_* environment variables, as older Pythons did.

    python tools/python_no_wmi.py <module> [args...]   e.g. ... pip install --user scons (tools/native.sh)
"""
import platform
import runpy
import sys


def _no_wmi(*_args):
    raise OSError("WMI skipped: it hangs on this PC")


platform._wmi_query = _no_wmi
module = sys.argv[1]
sys.argv = [module] + sys.argv[2:]
runpy.run_module(module, run_name="__main__", alter_sys=True)
