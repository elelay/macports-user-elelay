# Copyright (c) 2013 Eric Le Lay
# adapted from Jeff Hammel's autocomplete_newticket.js 0.11
# http://trac-hacks.org/wiki/AutocompleteUsersPlugin
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
"""
Utility script to get stats on the number of results from the database
for 2 letter queries.
"""
import psycopg2

from string import lowercase

def snd(x): return x[1]

conn = psycopg2.connect("dbname=macports user=macports")
cur = conn.cursor()

stats = []
for c1 in lowercase:
	for c2 in lowercase:
		data =  ("%" + c1 + c2 + "%",)
		cur.execute("SELECT count(*) from portfiles where name like %s;",data)
		stats.append((""+c1+c2,cur.fetchone()[0]))

stats.sort(key=snd)

for q,cnt in stats:
	print "%000d %s" % (cnt,q)
