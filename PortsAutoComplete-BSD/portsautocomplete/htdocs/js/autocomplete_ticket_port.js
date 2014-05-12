/* Copyright (C) 2013 Eric Le Lay
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR `AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/* 
 * adapted from Jeff Hammel's autocomplete_newticket.js 0.11
 * http://trac-hacks.org/wiki/AutocompleteUsersPlugin
 */


function update_maintainers(data,value){
	if(value != null && value.length > 1 && value[1] != ""){
		var firstmaintainer = value[1];
		/* must be fetched from the summary table, not the 'reassign to'
		   field because reassign to contains logged in user when the current
		   owner is macports-tickets
		 */
		var existingowner = $("td[headers=h_owner]>a").text().trim();
		var existingcc = $("#field-cc").val() == "" ? Array() : $("#field-cc").val().split(",\\s*");
		/*
		 * clear the owner if multiple port
		 */
		if(existingowner != ""
			&& existingowner != "macports-tickets@lists.macosforge.org"
			&& existingowner != firstmaintainer){
			existingcc.push(existingowner);
			existingcc.push(firstmaintainer);
			$("#action_reassign_reassign_owner").val(function(){
					return "";
			});
		}else{
			$("#action_reassign_reassign_owner").val(function(){
					return firstmaintainer;
			});
		}
		for(i=2;i<value.length;i++){
			if($.inArray(value[i],existingcc) == -1){
				existingcc.push(value[i]);
			}
		}
		$("#field-cc").val(function() {
				return existingcc.join(", ");
		});
		/* choose 'reassign to' */
		$("#action_reassign").attr('checked', 'checked');
	}
}

jQuery(document).ready(function($) {
	$("#field-port").autocomplete("../ports", { 
		multiple: true,
		formatItem: formatItem,
		delay:600,  /* wait as long as possible to avoid fetching all ports containing 'a' */
		multipleSeparator:" ",
		max: 100, /* more than that is too much to scroll into */
		minChars: 1,
		matchcontains: true, /* so that typing 'tk', then adding '2' works */
	}).result(update_maintainers);
});