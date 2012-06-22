/**
 * Left pad a string.
 * @param str the string to pad
 * @param len the desired length
 * @param c   the padding character, default='0'
 */
function extensions_pad(str, len, c) {
	str = str.toString();	// make sure it's a string
	c = c || '0';
	while (str.length < len) {
		str = c + str;
	}
	return str;
}

/**
 * Returns a string containing a YYYY-MM-DD formatted date.
 */
Date.prototype.toUTCDateString = function () {
	return extensions_pad(this.getUTCFullYear(), 2) + "-" + extensions_pad(this.getUTCMonth() + 1, 2) + "-" + extensions_pad(this.getUTCDate(), 2);
};

/**
 * Returns a string containing the UTC time in HH:MM:SS format.
 *   includeUTC         : append " UTC"
 *   includeMilliseconds: change format to HH:MM:SS.mmm
 */
Date.prototype.toUTCTimeString = function (includeUTC, includeMilliseconds) {
	return extensions_pad(this.getUTCHours(), 2) + ":" + extensions_pad(this.getUTCMinutes(), 2) + ":" + extensions_pad(this.getUTCSeconds(), 2) + (includeMilliseconds ? ("<span class=\"time-light\">." + extensions_pad(this.getUTCMilliseconds(), 3) + "</span>") : "") + (includeUTC ? " UTC" : "");
};

/**
 * Returns a date string in the format YYYY-MM-DD HH:MM:SS UTC
 */
Date.prototype.toUTCDateTimeString = function (includeUTC, includeMilliseconds) {
    return this.toUTCDateString() + " " + this.toUTCTimeString(includeUTC, includeMilliseconds);
};

/**
 * Parse a UTC date in the format YY-MM-DD HH:MM:SS
 * @param str the date string
 * @return the date as a timestamp
 */
Date.parseUTC = function(str) {
	return Date.UTC(parseInt(str.substr(0, 4), 10),
                    parseInt(str.substr(5, 2) - 1, 10),
                    parseInt(str.substr(8, 2), 10),
                    parseInt(str.substr(11, 2), 10),
	                parseInt(str.substr(14, 2), 10),
	                parseInt(str.substr(17), 10));
};
