import json;
import os;

glob f = open("plans/probes/_pywire_ascii.txt", "r"),
     ascii_wire: str = f.read();

with entry {
    f.close();

    if len(ascii_wire) > 0 {
        last: int = ord(ascii_wire[len(ascii_wire) - 1]);
        if last == 10 {
            ascii_wire = ascii_wire[0:len(ascii_wire) - 1];
        }
    }
}

glob val: any = json.loads(ascii_wire),
     redump: str = json.dumps(val);

with entry {
    print("CROSS_RE_DUMP " + redump);
}

glob d: dict[str, any] = val,
     ml: str = d["multiline"];

with entry {
    print("CROSS_ML_LEN " + str(len(ml)));
}
