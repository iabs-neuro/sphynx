import os
import subprocess
import sys


def test_engine_never_imports_qt():
    # The engine must stay usable headless and from the CLI, so importing it
    # must not drag Qt in. A fresh interpreter is the only honest check.
    code = (
        "import sphynx, sphynx.pipeline, sphynx.paradigms, sphynx.metrics, sys;"
        "print(any(m.startswith('PySide') for m in sys.modules))"
    )
    env = dict(os.environ)
    env["PYTHONPATH"] = "src"
    out = subprocess.run([sys.executable, "-c", code], capture_output=True,
                         text=True, env=env)
    assert out.returncode == 0, out.stderr
    assert out.stdout.strip() == "False", out.stderr
