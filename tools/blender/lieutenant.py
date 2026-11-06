"""The Agency lieutenant: the agent's body and kit (agent.py) in his own colours (his GuardData file,
data/enemies/agency_lieutenant.tres, names this model as his Model Scene), but bare-headed: a
younger officer's hard face, dark cropped hair, and the eyepiece over his left eye whose lens glows
like an agent's visor (agency_heads.py).

Rebuild:  .\\tools\\blender\\rebuild.ps1 lieutenant
"""
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import base_body as bb        # noqa: E402
import agent                  # noqa: E402
import agency_heads as ah     # noqa: E402
import face                   # noqa: E402
from paint import rgb         # noqa: E402

C = {k: rgb(v) for k, v in {
    "skin": "#cf9b78", "hair": "#3a2e26", "brow": "#231b17", "iris": "#4b3b2d", "lip": "#a06a5a",
    "lash": "#1d1613"}.items()}
# His face (face.py): late twenties, a hard set to it: level brows low over the eyes, a strong
# nose and jaw, a mouth turned down a little, a shadow of stubble.
FACE = face.look(face.MAN, eye_h=0.0058, eye_lo=0.0042, iris_r=0.0062, brow_z0=0.1180, brow_z1=0.1210,
                 brow_arch=0.0010, brow_thick=0.0042, nose=0.0195, jaw=0.005, chin=0.0068, smile=-0.0003,
                 stubble=0.25, lip_sat=0.25, skin=C["skin"], hair=C["hair"], brow=C["brow"],
                 lash_col=C["lash"], iris=C["iris"], lip=C["lip"])


def hairline(theta):
    """A cropped cut: a straight line across the brow, short at the sides and nape."""
    return bb.hair_line(theta) - 0.004


def build():
    return agent.build("lieutenant", officer=(FACE, ah.CROPPED, hairline), rank=1)


if __name__ == "__main__":
    ch = build()
    for name, part in ch.parts.items():
        print("CHARACTER part %s: %d triangles" % (name, part.tris()))
    ch.finish(animations=agent.animations)
