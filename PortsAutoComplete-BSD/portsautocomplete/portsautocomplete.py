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
PortsAutocomplete:
 - fill-in the port field for the ticket text input for existing ports.
 - fill-in the owner and cc fields based on selected port's maintainers.
All ticket modifications are done client-side in javascript.
Needs a postgresql database containing the portindex dump
(see http://trac.macports.org/ticket/40579)
"""

import fnmatch
import re

import psycopg2

from pkg_resources import resource_filename

from trac.core import *

from trac.config import ListOption
from trac.web.api import IRequestFilter
from trac.web.api import IRequestHandler
from trac.web.chrome import add_script
from trac.web.chrome import add_stylesheet
from trac.web.chrome import Chrome
from trac.web.chrome import ITemplateProvider 

class PortsAutoComplete(Component):

    implements(IRequestHandler, IRequestFilter, ITemplateProvider)
    selectfields = ['port']
    
    prefix = "portsautocomplete" # prefix for htdocs -- /chrome/prefix/...    

    _mixed_re = re.compile(r'^([^:]+):(.+)$')
	
    """add macports.org suffix or invert based on colons"""
    def get_maintainer_email(self, maintainer):
        if not maintainer:
            return ""
        match = self._mixed_re.match(maintainer)
        if match:
            return match.group(2) + "@" + match.group(1)
        return maintainer + "@macports.org"


    ### methods for IRequestHandler

    """Extension point interface for request handlers."""

    def match_request(self, req):
        """Return whether the handler wants to process the given request."""
        return req.path_info.rstrip('/') == '/ports'

    def process_request(self, req):
        """Serve ports query results in a text format suitable to jQuery autocomplete:
        PORTNAME|MAINTAINER_1|MAINTAINER_2|...
        one line per port.
        Mangles maintainers emails if request is not from logged-in session.
        nomaintainer and openmaintainer are filtered out
        Exact match is put to the top to ensure ports with common names (eg. tk,R)
        can be selected.
        
		q parameter is the port name substring to find
        limit parameter is the max number of results to return (limited to 100 anyway)
        """

        query = req.args.get('q', '').lower()
        limit = 100
        try:
        	limit = min(limit,int(req.args.get('limit','1000')))
        except ValueError:
        	pass
        
        chrome = Chrome(self.env)
        
        ports = []
        if len(query) > 0:
			conn = psycopg2.connect("dbname=macports user=macports")
			cur = conn.cursor()
			cur.arraysize = limit
			cur.execute("SELECT name from portfiles where name = %s ",(query,))
			exactmatch = cur.fetchone() is not None
			ports = [ row[0] for row in cur.fetchmany()]
			data = ("%" + query + "%", cur.arraysize)
			cur.execute("SELECT name from portfiles where name like %s order by name asc LIMIT %s;",data)
			ports = [ row[0] for row in cur.fetchmany()]
			cur.close()
			cur = conn.cursor()
			if exactmatch:
				ports.insert(0,query)
			for index,port in enumerate(ports):
				data = (port,)
				cur.execute("SELECT maintainer from maintainers where portfile = %s and maintainer not in ('nomaintainer','openmaintainer') order by is_primary desc;",data)
				maintainers = [chrome.format_author(req, self.get_maintainer_email(row[0]))
								for row in cur.fetchall()]
				ports[index] = "%s|%s" % (port,"|".join(maintainers))
			cur.close()
			conn.close()

        req.send('\n'.join(ports).encode('utf-8'), 'text/plain')


    ### methods for ITemplateProvider

    def get_htdocs_dirs(self):
        """Return a list of directories with static resources (such as style
        sheets, images, etc.)

        Each item in the list must be a `(prefix, abspath)` tuple. The
        `prefix` part defines the path in the URL that requests to these
        resources are prefixed with.
        
        The `abspath` is the absolute path to the directory containing the
        resources on the local file system.
        """

        return [(self.prefix, resource_filename(__name__, 'htdocs'))]

    def get_templates_dirs(self):
        """Return a list of directories containing the provided template
        files.
        No template for this plugin!
        """
        return []

    ### methods for IRequestFilter

    def post_process_request(self, req, template, data, content_type):
        """Insert css and javascript links - different for new or existing tickets.
           (this is the post_process_request method for genshi templates, apparently) 
        """
        if template == 'ticket.html':
            add_stylesheet(req, '%s/css/autocomplete.css' % self.prefix)
            add_script(req, '%s/js/autocomplete.js' % self.prefix)
            add_script(req, '%s/js/format_item.js' % self.prefix)
            if req.path_info.rstrip() == '/newticket':
                add_script(req, '%s/js/autocomplete_newticket_port.js' % self.prefix)
            else:
                add_script(req, '%s/js/autocomplete_ticket_port.js' % self.prefix)
        return (template, data, content_type)

    def pre_process_request(self, req, handler):
        """Called after initial handler selection, and can be used to change
        the selected handler or redirect request.
        
        Always returns the request handler, even if unchanged.
        """
        return handler
