package ;

import haxe.Curl;
import neko.Lib;
import neko.FileSystem;
import neko.io.File;
import neko.Sys;

using StringTools;

typedef RequestData = 
{
	var date : String;
	var method : String;
	var url : String;
	var headers : Array<String>;
	var params : Dynamic;
}

class Main 
{
	static function main()
	{
		var args = Sys.args();
		
		if (args.length == 3)
		{
			var baseUrl = args[0];
			var fname = args[1];
			if (FileSystem.exists(fname) && !FileSystem.isDirectory(fname))
			{
				makeRequest(baseUrl, loadRequestData(fname));
			}
			else
			{
				Lib.println("File '" + fname + "' does not exist.");
			}
		}
		else
		{
			Lib.println("WebTester make request tool.\nUsage: haxelib run WebTester <base_url> <request_file>");
		}
	}
	
	static function makeRequest(baseUrl:String, data:RequestData)
	{
		var url = baseUrl + data.url;
		
		Lib.println("method: " + data.method);
		Lib.println("   url: " + url);
		Lib.println("response:");
		var response = Curl.request(data.method, url, data.params, data.headers);
		Lib.println(response);
	}
	
	static function loadRequestData(fname:String) : RequestData
	{
		var text = File.getContent(fname);
		text = text.replace("\r\n", "\n");
		
		var blocks = text.split("\n\n");
		var dateAndMethodUrl = blocks[0].split("\n");
		var MethodAndUrl = dateAndMethodUrl[1].split(" ");
		
		var params : Dynamic = {};
		var post = blocks[2];
		for (s in post.split("&"))
		{
			var nameAndValue = s.split("=");
			var name = StringTools.urlDecode(nameAndValue[0]);
			var value = StringTools.urlDecode(nameAndValue[1]);
			Reflect.setField(params, name, value);
		}
		
		return {
			 date : dateAndMethodUrl[0]
			,method : MethodAndUrl[0]
			,url : MethodAndUrl[1]
			,headers : blocks[1].split("\n")
			,params : params
		};
	}
}