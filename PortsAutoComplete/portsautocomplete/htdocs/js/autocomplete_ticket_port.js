/* Copyright (c) 2013 Eric Le Lay
 * adapted from Jeff Hammel's autocomplete_ticket.js 0.11
 * http://trac-hacks.org/wiki/AutocompleteUsersPlugin
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

function update_maintainers(data,value){
	if(value != null && value.length > 1 && value[1] != ""){
		var firstmaintainer = value[1];
		var existingowner = $("#action_reassign_reassign_owner").val();
		var existingcc = $("#field-cc").val() == "" ? Array() : $("#field-cc").val().split(",\\s*");
		if(existingowner != "" && existingowner != firstmaintainer){
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