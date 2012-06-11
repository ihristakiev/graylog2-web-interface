$(document).ready(function() {
	
	/*
	 * Timer
	 */
	setInterval(function() {
		$("#top-timestamp").text(new Date().toUTCDateTimeString() + " UTC");
	}, 1000);
	
	/*
	 * Server-push
	 */
	var jug = new Juggernaut({
		port : 3001
	});
	var pushhandler = function(data) {
		data = JSON.parse(data);
		for (i in data)
			{
				insertMessage(data[data.length - i - 1]);	// invert order of block (sorts it by created_at asc)
			}
	};
	
	jug.subscribe("graylog2", pushhandler);
	
	/*
	 * Toggle button
	 */
	    $(".toggle-liveview").bind("click", function() {
	      if ($(this).hasClass("active")) {
	    	 // Pause server-push 
	    	 jug.unsubscribe("graylog2");
	    	  
	    	// housekeeping
	        $(this).removeClass("active");
	        $(this).attr("src", "/images/icons/sun.png");
	      } else {
	    	// Resume server-push  
	    	jug.subscribe("graylog2", pushhandler);
	    	  
	    	// housekeeping
	        $(this).attr("src", "/images/icons/sun_active.png");
	        $(this).addClass("active");
	      }
	    });
});

function insertMessage(message) {
//	var message = eval('(' + message.escapeSpecialChars() + ')'); // String ->
																	// JSON

	$("#messages").prepend(
			"<tr id="
					+ message._id
					+ " class=\"message-row\">"
					+ "<td>"
					+ new Date(message.created_at * 1000)
							.toUTCDateTimeString(false, true) + "</td>" + "<td>"
					+ message.host + "</td>" + "<td>"
					+ syslog_level_to_human(message.level) + "</td>"
					+ "<td>" + message.facility + "</td>"
					+ "<td colspan=\"2\">" + message.message + "</td>"
					+ "</tr>");
}

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
}

String.prototype.escapeSpecialChars = function() {
	return this.replace(/[\\]/g, '\\\\')
	.replace(/[\"]/g, '\\\"').replace(/[\/]/g, '\\/').replace(/[\b]/g, '\\b').replace(/[\f]/g, '\\f')
			.replace(/[\n]/g, '\\n').replace(/[\r]/g, '\\r').replace(/[\t]/g,
					'\\t');
};