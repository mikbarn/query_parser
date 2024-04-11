import re

sql_starts = {'select', 'create', 'drop', 'copy', 'with', 'update', 'delete', 'load', 'unload', 'insert', 'truncate'}

af_ts_re = re.compile('\[(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d),\d+\]\s+{{[_\w\.:\d]+}}\s+[A-Z]+ - ([^\n]+)\n?')

class Chunk:
    def __init__(self, src_file:str, start_line_number:int, starttime:str, meta=None):
        self.src_file = src_file
        self.start_line_number = start_line_number
        self.end_line_number = -1
        self.meta = meta
        self.starttime = starttime
        self.queries = []

    def __str__(self):
        return str(self.meta)+': ' + '\n'.join(self.queries)


_EX = 'Execute the query:'
_HAS_FINISHED = "' has finished"
def pass1(filename:str):
    with open(filename, 'r') as fd:
        lines = fd.readlines()

    events = []
    curr_event = None
    curr_query = False
    remainder = ""
    for line_no, _ln in enumerate(lines):
        try:
            dt, ts, meat = af_ts_re.match(_ln).groups()
        except Exception as err:
            print(f"Can't match line {line_no}: {_ln}")
        else:
            meat = remainder + ' ' + meat + ' '
            remainder = ""
            _m = meat.rstrip()
            if _m.endswith('Start.') or _m.endswith('Start to work.'):
                print(f'Start new event: {_ln}')
                curr_event = Chunk(filename, line_no, f"{dt} {ts}", meta=_m)
                events.append(curr_event)
                curr_query = False
            else:
                if curr_query:
                    if '--' in meat:
                        meat = meat[:meat.index('--')]
                    if ';' in meat:
                        idx = meat.index(';')
                        curr_event.queries[-1] += meat[:idx+1]
                        remainder = meat[idx+1:]
                        curr_query = False
                    elif _HAS_FINISHED in meat:
                        idx = meat.index(_HAS_FINISHED)
                        curr_event.queries[-1] += meat[:idx]
                        remainder = meat[idx+len(_HAS_FINISHED):]
                        curr_query = False
                    else:
                        curr_event.queries[-1] += f" {meat} "
                else:
                    new_query = False
                    try:
                        idx = meat.index(_EX)
                        temp = meat[idx + len(_EX):]


                        if "'" in temp and temp.index("'") <= 5:
                            meat = temp.lstrip(' ').lstrip("'")
                        else:
                            meat = temp
                        new_query = True

                    except ValueError:
                        if meat.lower().strip() in sql_starts:
                            new_query = True
                        else:
                            try:
                                idx = meat.index(' ')
                                word = meat[:idx].strip()
                                if word.lower() in sql_starts:
                                    new_query = True
                            except ValueError:
                                print('Strange line: ', _ln)

                    if new_query:
                        print(f'start new query on {_ln}')
                        curr_query = True
                        if not curr_event:
                            curr_event = Chunk(filename, line_no, f"{dt} {ts}", meta='unknown')
                            events.append(curr_event)
                        curr_event.queries.append(meat)
            #print(meat)
    return events


seen = set()
red = 0
tot = 0
qs = []
if __name__ == '__main__':
    rval = pass1('tsp/dmlog_samp.txt')
    print(len(rval))
    for ev in rval:
        for _q in ev.queries:
            tot+=1
            if _q in seen:
                red += 1
            else:
                qs.append(_q)
            seen.add(_q)
    print(f"{red} duplicate queries out of {tot}")
        # if ev.queries:
        #     print(ev)
import os
with open(os.path.expanduser('~/Desktop/trashqs.sql'), 'w') as fd:
    for _q in qs:
        if ';' in _q:
            _i = _q.rindex(';')
            _q = _q[:_i+1]
        fd.write(_q+'\n\n\n')