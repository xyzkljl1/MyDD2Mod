# Script to generate an IDA python script to name all of the
# Functions in the IL2CPP Dump.
# partial credits to deepdarkkapustka for the script this is based off of (@muhopensores on github)
import json
import fire
import os

def main(il2cpp_path = None):
    with open(il2cpp_path, "r", encoding="utf8") as f:
        il2cpp_dump = json.load(f)

    out_lines = []

    for class_name, entry in il2cpp_dump.items():
        if "fields" in entry:
            for field_name, field_entry in entry["fields"].items():
                if "offset_from_base" in field_entry:
                    out_lines.append(class_name+" "+field_name+" "+str(field_entry["offset_from_base"])+"\n")

    with open("address.list", "w", encoding="utf8") as f:
        f.writelines(out_lines)

    print("Done!")


if __name__ == '__main__':
    fire.Fire(main)
