$(document).ajaxSend(function(e, xhr, options) {
  var token = $("meta[name='csrf-token']").attr("content");
  xhr.setRequestHeader("X-CSRF-Token", token);
});

$(document).ready(function(){
	
    var login_name = $("#login").html()+ "_" + Math.floor(Math.random()*10000+1);

    // Hide notifications after some time.
    setInterval(function() {
      $(".notification-flash").hide("drop");
    }, 3500);

    // Stream rule form.
    $('#streamrule_rule_type').bind('change', function() {
        $('.stream-value-field').hide();
        $('.stream-value-help').hide();
        $('.stream-value-field').attr("disabled", true);

        help = null;
        master = null;
        switch(this.value) {
            case '1':
                field = $('.stream-value-message');
                break;
            case '2':
                field = $('.stream-value-host');
                break;
            case '3':
                field = $('.stream-value-severity');
                break;
            case '4':
                field = $('.stream-value-facility');
                break;
            case '5':
                field = $('.stream-value-timeframe');
                help = $('#stream-value-timeframe-help');
                break;
            case '6':
                field = $('.stream-value-additional-field');
                help = $('#stream-value-additional-field-help');
                break;
            case '8':
                field = $('.stream-value-severity-or-higher');
                break;
            case '9':
                field = $('.stream-value-host-regex');
                notify("Remember to possibly escape characters in the regular expression." +
                       "A typical mistake is forgetting to escape dots in host names.");
                break;
            case '10':
                field = $('.stream-value-fullmessage');
                break;
            case '11':
                field = $('.stream-value-filename');
                notify("Remember to possibly escape characters in the regular expression." +
                       "A typical mistake is forgetting to escape the dot in filenames.");
                break;
        }
        field.removeAttr("disabled");
        field.show();

        if (help != null) { help.show(); }
    });

    // Stream Quick chooser
    $('#favoritestreamchooser_id').bind('change', function() {
       window.location = "/streams/show/" + parseInt(this.value);
    });

    // Full message view resizing.
    $('#messages-show-message-full').css('width', parseInt($('#content').css('width'))-15);
    $('#messages-show-message-full').css('height', parseInt($('#messages-show-message-full').css('height'))+10);

    // Visuals: Message spread permalink
    $('#visuals-spread-hosts-permalink-link').bind('click', function() {
      $('#visuals-spread-hosts-permalink-link').hide();
      $('#visuals-spread-hosts-permalink-content').show();
      return false;
    });

    $('#analytics-new-messages-update-range').numeric();
    // Visuals: Update of new messages graph.
    $('#analytics-new-messages-update-submit').bind('click', function() {
      i = $('#analytics-new-messages-update-range');
      v = parseInt(i.val());
      
      if (v <= 0) {
        return false;
      }

      // Possibly multiply if days or weeks was selected as range.
      if ($('#range_type_days').attr("checked")) {
        range_type = "days";
        range_num = v*24;
      } else if($('#range_type_weeks').attr("checked")) {
        range_type = "weeks";
        range_num = v*24*7;
      } else {
        range_type = "hours";
        range_num = v;
      }

      // Show loading message.
      $("#analytics-new-messages-update-loading").show();

      // Update graph.
      $.post($(this).attr("data-updateurl") + "&hours=" + range_num, function(data) {
        json = eval('(' + data + ')');

        // Plot is defined inline. (I suck at JavaScript)
        plot(json.data);

        // Update title.
        $('#analytics-new-messages-range').html(v);
        $('#analytics-new-messages-range-type').html(range_type);

        // Hide loading message.
        $("#analytics-new-messages-update-loading").hide();
      });

      return false;
    });

    // Hide sidebar.
    $("#sidebar-hide-link").bind('click', function() {
      $("#main-right").hide();
      $("#main-left").animate({ width: '100%' }, 700);
      return false;
    });

    // Favorite streams: Sparklines.
    $(".favorite-stream-sparkline").sparkline(
      "html",
      {
        type: "line",
        width: "40px",
        lineColor: "#009D00",
        fillColor: "#fdd",
        spotColor: false,
        minSpotColor: false,
        maxSpotColor: false
      }
    );

    // Entity lists: Sparklines.
    $(".el-e-sparkline").sparkline(
      "html",
      {
        type: "line",
        width: "70px",
        height: "23px",
        lineColor: "#009D00",
        fillColor: "#fdd",
        spotColor: false,
        minSpotColor: false,
        maxSpotColor: false
      }
    );

    // AJAX trigger
    $(".ajaxtrigger").bind("click", function() {
      field = $(this);
      loading = $("#" + field.attr("id") + "-ajaxtrigger-loading");
      done = $("#" + field.attr("id") + "-ajaxtrigger-done");

      field.attr("disabled","disabled");
      done.hide();
      loading.show();
      $.post(field.attr("data-target"), function(data) {
        field.removeAttr("disabled");
        loading.hide();
        done.show();
      });
    });

    // Stream alerts: Inputs only numeric.
    $('#streams-alerts-limit').numeric();
    $('#streams-alerts-timespan').numeric();

    // Stream descriptions.
    $(".stream-description-change").bind("click", function() {
      $("#streams-description-text").hide();
      $("#streams-set-description").show();
    });

    // Awesome submit links
    $(".submit-link").bind("click", function() {
      if ($(this).attr("data-nowait") == undefined) {
        $(this).html("Please wait...");
      }
      
      if ($(this).attr("data-confirm") == undefined) {
        // Directly follow form if no confirmation was requested.
        $(this).parent().submit();
        return false;
      }

      if (confirm($(this).attr("data-confirm"))) {
        $(this).parent().submit();
      }

      return false;
    });

    $("a").bind("click", function(){
      // Avoid double handling.
      if ($(this).hasClass("submit-link")) {
        return false;
      }

      if ($(this).attr("data-confirm") == undefined) {
        return true;
      } else {
        if (confirm($(this).attr("data-confirm"))) {
          return true;
        } else {
          return false;
        }
      }
    });

    // Show full message in sidebar.
    bindMessageSidebarClicks();

    // User role settings in new user form.
    $("#user_role").bind("change", function() {
        if ($(this).val() == "reader") {
          $(".users-streams").show();
        } else {
          $(".users-streams").hide();
        }
    });

    // Set sidebar to a fixed height to get the scrollbar in lower resolutions.
    $("#sidebar").css("height", $(window).height()-120);

    // Facilities title change.
    $(".facilities-edit-link").bind("click", function() {
      $(this).hide();
      $(this).parent().next().show();
      return false;
    });


    // Additional field quickfilter.
    $("#messages-quickfilter-add-additional").bind("click", function() {
      field = "<dt><input name='filters[additional][keys][]' type='text' class='messages-quickfilter-additional-key' /></dt>"
      field += "<dd><input name='filters[additional][values][]' type='text' class='messages-quickfilter-additional-value' /></dd>"

      $("#messages-quickfilter-fields").append(field);
      return false;
    });
    

    
    // DateTimePickers    
	var maxDate = new Date();
	maxDate.setHours(23);
	maxDate.setMinutes(59);
	maxDate.setSeconds(59);
	maxDate.setMilliseconds(999);
	
	// If the local date is not equal to the UTC date, add or subtract 1.
	maxDate.setDate(maxDate.getUTCDate());
    
	var dtpOptions = {
		showSecond: true,
		dateFormat: "yy-mm-dd",
		timeFormat: "hh:mm:ss",
		maxDate: maxDate
	};
	var dtp_now = new Date();
	var dtp_1hourAgo = new Date(dtp_now.getTime() - 3600000);	 //1 hour ago
//	var dtp_10minAgo = new Date(dtp_now.getTime() -  600000);	 //10 min ago
	
	// Due to refresh issues, set a default value only if one is already not there
	if ($("#filters_jump_to").val() === "")
	{
		$("#filters_jump_to").val(dtp_1hourAgo.toUTCDateTimeString());
	}
//	if ($("#filters_to").val() === "")
//	{
//		$("#filters_to").val(dtp_now.toUTCDateTimeString());
//	}
	
	$("#filters_jump_to").datetimepicker(dtpOptions);
//	$("#filters_to").datetimepicker(dtpOptions);
	
    // Key bindings.
    //standardMapKeyOptions = { overlayClose:true }
    //$.mapKey("s", function() { $("#modal-stream-chooser").modal(standardMapKeyOptions); });
    //$.mapKey("h", function() { $("#modal-host-chooser").modal(standardMapKeyOptions); });
  
//    setInterval(function(){
//      // Update current throughput every 5 seconds
//      $.post("/health/currentthroughput", function(data) {
//        json = eval('(' + data + ')');
//        count = $(".health-throughput-current");
//        count.html(json.count);
//        count.fadeOut(200, function() {
//          count.fadeIn(200);
//        });
//      });
//  
//      // Update message queue size every 5 seconds
//      $.post("/health/currentmqsize", function(data) {
//        mqjson = eval('(' + data + ')');
//        mqcount = $(".health-mqsize-current");
//        mqcount.html(mqjson.count);
//        mqcount.fadeOut(200, function() {
//          mqcount.fadeIn(200);
//        });
//      });
//    }, 5000);
    
    /*
     * Hide next-page and last-page links, instead use AJAX when bottom is reached
     */
    $(".next-page").hide();
    $(".previous-page").hide();

    $("#main-right").hide();
    $("#main-left").css("width", '100%');
    
    /*
	 * Server-push
	 */    
	var jug = new Juggernaut({
		port : 3001
	});    
	var pushHandler = function(data) {
		data = JSON.parse(data);
		for (i in data)
		{
			prependMessage(data[data.length - i - 1]);	// invert order of block (sorts it by created_at asc)
		}
		
		// Refresh links to messages
	    bindMessageSidebarClicks();
	};   

	jug.subscribe(login_name, pushHandler);
	subscribed = true;
   
	/*
	 * Toggle button
	 */
    $(".toggle-liveview").bind("click", function() {
      if (!$(this).hasClass("inactive")) {
    	// Pause server-push 
    	jug.unsubscribe(login_name);
        subscribed = false;
    	  
    	// housekeeping
        $(this).addClass("inactive");
        $(this).find("img").attr("src", "/images/icons/start.png");
        $(this).attr("title", "Start live-view");
        $(this).attr("alt", "Start live-view");
      } 
      else {
    	// Resume server-push  
    	jug.subscribe(login_name, pushHandler);
        subscribed = true;
    	  
    	// housekeeping
        $(this).find("img").attr("src", "/images/icons/stop.png");
        $(this).attr("title", "Stop live-view");
        $(this).attr("alt", "Stop live-view");
        $(this).removeClass("inactive");
      }
    });
    
    // Clear filters
    $("#clear-quickfilter").bind("click", function() {
    	// Set to default fields
    	$("#filters_message").val("");
    	$("#filters_facility").val("");
    	$("#filters_host").val("");
    	$("#filters_severity").val("");
    	$("#filters_severity_above").attr('checked', false);
    	$("#filters_message_case").attr('checked', false);
    	$("#filters_facility_case").attr('checked', false);
    	
    	// Clear filters on server as well
    	$("#apply-quickfilter").click();
    	
    	// prevent the click on the link from propagating
    	return false;
    });
	

    
    // Jump to
    $("#apply_quickfilter_jump_to").bind("click", function() {
    	message = $("#filters_message").val();
    	facility = $("#filters_facility").val();
    	host = $("#filters_host").val();
    	severity = $("#filters_severity").val();
    	severity_above = $("#filters_severity_above").is(':checked');  
    	message_case = $("#filters_message_case").is(':checked');
    	facility_case = $("#filters_facility_case").is(':checked');
    	
    	to = $("#filters_jump_to").val();
    	
    	href =    "/messages?filters[message]=" + message +
	       				   "&filters[message_case]=" + message_case +
					       "&filters[facility]=" + facility +
					       "&filters[facility_case]=" + facility_case +
					       "&filters[host]=" + host +
					       "&filters[severity]=" + severity +
					       "&filters[severity_above]=" + severity_above +
					       "&filters[to]=" + to +
					       "&login=" + login_name ; 
    	
    	$.get(href + "&applyFilter=true&page=1", 
       		 function(data){
       		 // Clear old table
       		 $("#messages-tbody").children().remove();
       		 
       		 // Populate table with new content
       		 data = JSON.parse(data);
       		 for (i in data)
   			 {
       			 appendMessage(data[i]);
   			 }
       		 
       		 // Update scroll-down link
       		 $(".next-page").attr("href", href + "&page=2");

     		 // Refresh links to messages
     	     bindMessageSidebarClicks();
     	     
     	     // Stop live-view
     	     $(".toggle-liveview").click();
       	});
    	
    	// prevent the click on the link from propagating
       	return false;
    	
    });
    
    // Quickfilter
    $('#messages-show-quickfilter').bind('click', function() {
        var showLink = $('#messages-show-quickfilter');
        if (showLink.hasClass('messages-show-quickfilter-expanded')) {
            // Quickfilter is expanded. Small down on click.
            showLink.removeClass('messages-show-quickfilter-expanded');

            // Hide quickfilters.
            $('#messages-quickfilter').hide();
            $('#quickfilter_jump_to').hide();
            
            
        } else {
            // Quickfilter is not expanded. Expand on click.
            showLink.addClass('messages-show-quickfilter-expanded');

            // Show quickfilters.
            $('#messages-quickfilter').fadeIn(800);
            $('#quickfilter_jump_to').fadeIn(800);
        }
    });
	
    /*
     * AJAX
     */
    
    // Get more data if we reach bottom - see http://stackoverflow.com/questions/3898130/how-to-check-if-a-user-has-scrolled-to-the-bottom
    var next_scroll_exists= true;
    
    $(window).scroll(function() {
    	if($(window).scrollTop() + $(window).height() >= $(document).height() - 1) {
			href = $(".next-page").attr("href");
		    if (href === undefined) return;
			if ($("#gln").is(":visible")) return;
			if (!next_scroll_exists)
			{		
				// Modify request for even further historical data
				///.*from.{0,5}=(.*)&filters.{0,5}host.*&filters.{0,5}to.{0,5}=(.*)&page.*$/.exec($(".next-page").attr("href"))
				return;
			}
			
	        $("#gln").show();
			// Bottom reached, do AJAX
			$.get(href + "&onlyData=true", function(data) {
					data = JSON.parse(data);
					if (data.length == 0) {
						// stop if no data returned
						next_scroll_exists = false;
						return;
					}
					next_scroll_exists = true;
					for (i in data)
					{
						appendMessage(data[i]);	// inser message
					}
					
					// update link to next page
				   href = $(".next-page").attr("href");
				   if (href === undefined) return;
				   page = parseInt(/.page=(\d+).*/g.exec(href)[1]); // get page number (and convert it from String-> int)
				   $(".next-page").attr("href", href.replace(new RegExp("page="+page), "page=" + (page+1)) );				   
	
				   // Refresh links to messages
				   bindMessageSidebarClicks();
				   $("#gln").hide();
			}).onerror = function() { $("#gln").hide(); };	
	   }
    });
    
    // Apply filter.
    $("#apply-quickfilter").bind("click", function() {
    	// Notify server via AJAX
    	message = $("#filters_message").val();
    	facility = $("#filters_facility").val();
    	host = $("#filters_host").val();
    	severity = $("#filters_severity").val();
    	severity_above = $("#filters_severity_above").attr('checked'); 
    	message_case = $("#filters_message_case").is(':checked');
    	facility_case = $("#filters_facility_case").is(':checked');
    	
    	href =    "/messages?filters[message]=" + message +
		   				   "&filters[message_case]=" + message_case +
					       "&filters[facility]=" + facility +
		   				   "&filters[facility_case]=" + facility_case +
					       "&filters[host]=" + host +
					       "&filters[severity]=" + severity +
					       "&filters[severity_above]=" + severity_above +
					       "&login=" + login_name ;

        $("#gln").show();
    	$.get(href + "&applyFilter=true&page=1", 
    		 function(data){
    		 // Clear old table
    		 $("#messages-tbody").children().remove();
    		 
    		 // Populate table with new content
    		 data = JSON.parse(data);
    		 for (i in data)
			 {
    			 appendMessage(data[i]);
			 }
 		 
    		 // Update scroll-down link
    		 $(".next-page").attr("href", href + "&page=2");  
    		 
			 // Refresh links to messages
		     bindMessageSidebarClicks();
		     $("#gln").hide();
    	}).onerror = function(jqXHR, textStatus) { $("#gln").hide(); };	

    	// prevent the click on the link from propagating
    	return false;
    });	 
    
    // Jump Up and Jump Down buttons
    $(".jump_up").bind("click", function(){
    	
	    // Do nothing if we are in 'live-view' mode
	    if (subscribed == true) return;
	    
	    firstRow = $("#messages-tbody").find("tr")[0];
	    if (firstRow === undefined)
    	{
    	   latest_timestamp = 0;
    	}
	    else
    	{
	    	latest_timestamp = firstRow.children[0].innerHTML.replace( new RegExp("<span.*>(.*)</span>"),"$1");
    	}
	    
    	$.get("/messages?login=" + login_name + 
    			       "&jumpUp=true" +
  				       "&latest_timestamp=" + latest_timestamp
    			
    			    , function(data){
					new_to = parseFloat(data); // String-> Float
					if (new_to == 0) return;
					href = "/messages?login=" + login_name +
							        "&to=" + new_to;
					ajax_helper(href);
    	});
    	
    	return false;
    });
    
    $(".jump_down").bind("click", function(){    	
		href = $(".next-page").attr("href");
	    if (href === undefined) return;
	    

	    // Stop server-push if we are in 'live-view' mode
	    if (subscribed == true) $(".toggle-liveview").click();
	    
//		if (!next_exists)
//		{		
//			// Modify request for even further historical data
//			///.*from.{0,5}=(.*)&filters.{0,5}host.*&filters.{0,5}to.{0,5}=(.*)&page.*$/.exec($(".next-page").attr("href"))
//		}    		
		
		$.get(href + "&onlyData=true"
		      , function(data) {
			data = JSON.parse(data);
			if (data.length == 0) {
				return; // stop if no data returned
			}

	    	// Clear current messages table
	    	$("#messages-tbody").empty();
			
			for (i in data)
			{
				appendMessage(data[i]);	// invert order of block (sorts it by created_at asc)
			}
			
			// update link to next page
		   page = parseInt(/.page=(\d+).*/g.exec(href)[1]); // String-> int
		   $(".next-page").attr("href", href.replace(new RegExp("page="+page), "page=" + (page+1)) );				   

		   // Refresh links to messages
		   bindMessageSidebarClicks();
		});	
		
    	return false;
    });
    
});

function buildHTMLMessageFrom(message) {
	return "<tr id=" + message.id + " class=\"message-row\">"
				+ "<td>" + new Date(message.created_at * 1000).toUTCDateTimeString(false, true) + "</td>" 
				+ "<td>" + message.host + "</td>" 
				+ "<td>"+ syslog_level_to_human(message.level) + "</td>"
				+ "<td>" + message.facility + "</td>"
				+ "<td colspan=\"2\">" + message.message.trim() + "</td>"
				+ "</tr>";
};

function prependMessage(message) {
	$("#messages-tbody").prepend(buildHTMLMessageFrom(message));
};

function appendMessage(message) {
	$("#messages-tbody").append(buildHTMLMessageFrom(message));
};

function syslog_level_to_human(level) {
	if (level == null)
		return "None"
	switch (level) {
	case 0:
		return "Emerg";
	case 1:
		return "Alert";
	case 2:
		return "Crit";
	case 3:
		return "Error";
	case 4:
		return "Warn";
	case 5:
		return "Notice";
	case 6:
		return "Info";
	case 7:
		return "Debug";
	default:
		return "Invalid";
	}
};

function ajax_helper(href) {
	$.get( href + "&page=1" + "&jumpUp=false",    						
			function(data1){
       		 // Clear old table
       		 $("#messages-tbody").children().remove();
       		 // Populate table with new content
       		 data = JSON.parse(data1);
       		 for (i in data)
   			 {
       			 appendMessage(data[i]);
   			 }

       		 // Update scroll-down link
       		 $(".next-page").attr("href", href + "&page=2");	

     		// Refresh links to messages
     	    bindMessageSidebarClicks();
	});
};
   
function buildHostCssId(id) {
  return "visuals-spread-hosts-" + id.replace(/=/g, '');
};

function bindMessageSidebarClicks() {
  // Use a named function here to avoid multiple click handlers being fired per click.
  // http://stackoverflow.com/questions/6682434/jquery-multiple-binds
  $(".message-row").bind("click", click_handler);
};

function click_handler() {
	row = $(this);
    already_selected = row.hasClass("isSelected");
    target = relative_url_root + "/messages/" + row.attr("id") + "?partial=true";
    
    if (!already_selected)
	{
    	// Clear selection from everything else
    	$(".message-row").each(function(){
    		if ($(this) != row) $(this).removeClass('isSelected');
    	});
    	
  	    // Add selection to current element
	    row.addClass("isSelected");	
	    
	    
        $("#gln").show();
    	$.post(target, function(data) {
	      $("#sidebar-inner").html(data);

	      // Show sidebar if hidden.
	      if (!$("#main-right").is(":visible")) {
	          $("#main-right").show();
	      }	      
	      
	      $("#gln").hide(); 
    	}).onerror = function(jqXHR, textStatus) { $("#gln").hide(); };	
    	
	}
    else
	{	      
		  row.removeClass("isSelected");
	      // Hide sidebar if shown.
	      if ($("#main-right").is(":visible")) {
	          $("#main-right").hide();
	      }
	}
    
    // Prevent event bubbling
    // http://stackoverflow.com/questions/512010/why-does-my-jquery-alert-show-twice
    return false;
};

// srsly, javascript... - http://stackoverflow.com/questions/1219860/javascript-jquery-html-encoding
function htmlEncode(v) {
  return $('<div/>').text(v).html();
};

function notify(what) {
  $.gritter.add({
    title: "Notification",
    text: what
  })
};
