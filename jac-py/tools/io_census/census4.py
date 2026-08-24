import json
import csv
import os

R = __import__("os").environ.get("IO_CENSUS_ROOT4", "/var/tmp/qr-census4")
os.makedirs(R, exist_ok=True)

def check(name, fn):
    try:
        fn()
        print("OK", name)
    except Exception as e:
        print("FAIL", name, type(e).__name__, e)

def p_json_file_roundtrip():
    data = {"a": [1, 2.5, None, True], "b": {"c": "s"}}
    with open(R + "/d.json", "w") as f:
        json.dump(data, f)
    with open(R + "/d.json") as f:
        assert json.load(f) == data

def p_json_lines():
    lines = [{"i": i} for i in range(3)]
    with open(R + "/jl.json", "w") as f:
        for x in lines:
            f.write(json.dumps(x) + "\n")
    back = []
    with open(R + "/jl.json") as f:
        for ln in f:
            back.append(json.loads(ln))
    assert back == lines

def p_csv_roundtrip():
    rows = [["name", "age"], ["alice", "30"], ["bob", "25"]]
    with open(R + "/t.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerows(rows)
    with open(R + "/t.csv", newline="") as f:
        got = list(csv.reader(f))
    assert got == rows

def p_csv_dictreader():
    with open(R + "/t.csv", newline="") as f:
        r = csv.DictReader(f)
        recs = list(r)
    assert recs[0] == {"name": "alice", "age": "30"}

def p_shelve_like_pickle():
    import pickle
    obj = {"k": [1, "x"], "n": (3.5,)}
    with open(R + "/p.pkl", "wb") as f:
        pickle.dump(obj, f)
    with open(R + "/p.pkl", "rb") as f:
        assert pickle.load(f) == obj

check("json_file_roundtrip", p_json_file_roundtrip)
check("json_lines_pattern", p_json_lines)
check("csv_writerows_roundtrip", p_csv_roundtrip)
check("csv_dictreader", p_csv_dictreader)
check("pickle_binary_file", p_shelve_like_pickle)
print("CENSUS4-DONE")
