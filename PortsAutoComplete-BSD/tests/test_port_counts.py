# Copyright (C) 2013 Eric Le Lay
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:

# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
# 3. The name of the author may not be used to endorse or promote
#    products derived from this software without specific prior
#    written permission.

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR `AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# adapted from Jeff Hammel's autocompleteusers.py 0.11
# http://trac-hacks.org/wiki/AutocompleteUsersPlugin
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
