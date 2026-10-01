"""Read GUT JUnit evidence independently with the Python standard library."""

import json
import sys
import xml.etree.ElementTree as ET


def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage: read-junit.py <report.xml>")
    root = ET.parse(sys.argv[1]).getroot()
    if root.tag != "testsuites":
        raise ValueError(f"Expected testsuites, received {root.tag}")
    cases = []
    for case in root.findall(".//testcase"):
        cases.append(
            {
                "name": case.attrib["name"],
                "classname": case.attrib["classname"],
                "status": case.attrib["status"],
                "assertions": int(case.attrib["assertions"]),
                "failures": [node.text or "" for node in case.findall("failure")],
                "errors": [node.text or "" for node in case.findall("error")],
                "skipped": len(case.findall("skipped")),
            }
        )
    result = {
        "tests": len(cases),
        "declared_tests": int(root.attrib["tests"]),
        "declared_failures": int(root.attrib["failures"]),
        "assertions": sum(case["assertions"] for case in cases),
        "failures": sum(len(case["failures"]) for case in cases),
        "errors": sum(len(case["errors"]) for case in cases),
        "skipped": sum(case["skipped"] for case in cases),
        "cases": cases,
    }
    if result["tests"] != result["declared_tests"]:
        raise ValueError("Declared test count differs from actual testcase count")
    if result["failures"] != result["declared_failures"]:
        raise ValueError("Declared failures differ from actual failure elements")
    if not cases or any(case["assertions"] < 1 for case in cases):
        raise ValueError("Empty tests or tests without assertions are not evidence")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, ET.ParseError) as error:
        print(f"JUnit evidence rejected: {error}", file=sys.stderr)
        sys.exit(1)
