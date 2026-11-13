"""Add a race's virtual marks to its GPX files as waypoints, so any GPX viewer (and our tools) show the course.

Usage: python -I tools/real_races/add_course_to_gpx.py <course.json> <folder with .gpx files> <out folder>

The course file (tools/real_races/courses/*.json) holds the marks, the start line and the finish as latitude and
longitude, drawn by Max on a picture of the tracks. For every GPX file in the folder this writes a copy into the out
folder with one waypoint (<wpt>) per mark, one per end of the start line and one for the finish, placed before the
track as GPX 1.1 requires. The tracks themselves are copied unchanged. The originals are not touched.
The GPX files hold the riders' names: keep the copies in .sim_output/ (ignored by git).
Report: Documentation/reports/real_races/metasail_event930.md (section 13)
"""
import glob
import json
import os
import sys
from xml.sax.saxutils import escape


def waypoint(lat, lon, name, description):
    return (f'  <wpt lat="{lat}" lon="{lon}">\n'
            f'    <name>{escape(name)}</name>\n'
            f'    <desc>{escape(description)}</desc>\n'
            f'    <sym>Buoy</sym>\n'
            f'  </wpt>\n')


def course_waypoints(course):
    out = []
    line = course['start_line']
    out.append(waypoint(line['end_1']['lat'], line['end_1']['lon'], 'Start line end 1', line.get('note', '')))
    out.append(waypoint(line['end_2']['lat'], line['end_2']['lon'], 'Start line end 2', line.get('note', '')))
    for mark in course['marks']:
        out.append(waypoint(mark['lat'], mark['lon'], f"Mark {mark['name']} ({mark['rounding']})", mark.get('note', '')))
    finish = course.get('finish')
    if finish:
        label = 'Finish (provisional)' if finish.get('provisional') else 'Finish'
        out.append(waypoint(finish['lat'], finish['lon'], label, finish.get('note', '')))
    return ''.join(out)


def main():
    course = json.load(open(sys.argv[1], encoding='utf-8'))
    out_dir = sys.argv[3]
    os.makedirs(out_dir, exist_ok=True)
    points = course_waypoints(course)
    for path in sorted(glob.glob(os.path.join(sys.argv[2], '*.gpx'))):
        text = open(path, encoding='utf-8-sig').read()
        where = text.find('<trk>')
        if where < 0:
            print(f'skipped (no <trk>): {path}')
            continue
        marked = text[:where] + points.lstrip() + '  ' + text[where:]
        target = os.path.join(out_dir, os.path.basename(path))
        open(target, 'w', encoding='utf-8').write(marked)
        print(f'{target}: {points.count("<wpt")} waypoints added')


if __name__ == '__main__':
    main()
