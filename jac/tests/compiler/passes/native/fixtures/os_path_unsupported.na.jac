variant native;

import os;

with entry {
    print(os.path.getmtime("/tmp/anything"));
}
