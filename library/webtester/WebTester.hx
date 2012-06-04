package webtester;

#if php
import php.Lib;
import php.FileSystem;
import php.io.File;
import php.io.Path;
import php.Web;
#elseif neko
import neko.Lib;
import neko.FileSystem;
import neko.io.File;
import neko.io.Path;
import neko.Web;
#end

import haxe.Stack;
import microtime.Date;

using StringTools;

class WebTester 
{
	public var baseRequestStorePath : String;
	
	var currentRequestsDirectory : String;
	var longRequestsDirectory : String;
	var exceptionRequestDirectory : String;
	
	var maxRequestDuration : Int;
	
	public function new(baseRequestStorePath="temp/requests", maxRequestDuration=300000)
	{
		baseRequestStorePath = baseRequestStorePath.replace("\\", "/");
		
		this.baseRequestStorePath = baseRequestStorePath;
		this.currentRequestsDirectory = baseRequestStorePath + "/current";
		this.longRequestsDirectory = baseRequestStorePath + "/long";
		this.exceptionRequestDirectory = baseRequestStorePath + "/exception";
		this.maxRequestDuration = maxRequestDuration;
	}
	
	public function run(runSiteFunc:Void->Void) 
	{
		Sys.setCwd(Web.getCwd());
		
		createDirectory(currentRequestsDirectory);
		createDirectory(longRequestsDirectory);
		createDirectory(exceptionRequestDirectory);
		
		processLongRequests();
		
		var requestID = saveRequestData();
		try
		{
			runSiteFunc();
			
			deleteOrMoveRequestData(requestID);
		}
		catch (e:Dynamic)
		{
			processExceptionRequest(requestID, e);
		}
	}
	
	function createDirectory(path:String)
    {
        if (!FileSystem.exists(path))
		{
			path = path.replace('\\', '/');
			var dirs : Array<String> = path.split('/');
			for (i in 0...dirs.length)
			{
				var dir = dirs.slice(0, i + 1).join('/');
				if (!dir.endsWith(':'))
				{
					if (!FileSystem.exists(dir))
					{
						FileSystem.createDirectory(dir);
					}
				}
			}
		}
    }
	
	function getTimeString(time:Float) : String
	{
		var s = Std.string(time);
		if (s.indexOf(".") >= 0)
		{
			s = s.substr(0, s.indexOf("."));
		}
		return s;
	}
	
	function getUniqueString() : String
	{
		return getTimeString(Date.now().getTime()) + "_" + Std.string(Std.int(Math.random() * 99999)).lpad("0", 5);
	}
	
	function saveRequestData() : String
	{
		var requestID = getUniqueString();
		
		var fname = currentRequestsDirectory + "/" + requestID;
		
		var fout = File.write(fname);
		
		fout.writeString(Date.now().toString() + "\n");
		
		var paramsString = Web.getParamsString();
		fout.writeString(Web.getMethod() + " " + Web.getURI() + (paramsString != null && paramsString != "" ? "?" + paramsString:"") + "\n");
		
		fout.writeString("\n");
		
		for (header in Web.getClientHeaders())
		{
			fout.writeString(header.header + ": " + header.value + "\n");
		}
		
		fout.writeString("\n");
		
		var postData = Web.getPostData();
		fout.writeString(postData!=null ? postData : "");
		
		fout.close();
		
		return requestID;
	}
	
	function deleteOrMoveRequestData(requestID:String)
	{
		var fname = currentRequestsDirectory + "/" + requestID;
		
		if (FileSystem.exists(fname))
		{
			var nowTime = Date.now().getTime();
			var stat = FileSystem.stat(fname);
			if (nowTime - stat.mtime.getTime() > maxRequestDuration)
			{
				FileSystem.rename(fname, longRequestsDirectory + "/" + requestID);
			}
			else
			{
				FileSystem.deleteFile(fname);
			}
		}
	}
	
	function processExceptionRequest(requestID:String, e:Dynamic)
	{
		var fname = currentRequestsDirectory + "/" + requestID;
		
		if (FileSystem.exists(fname))
		{
			FileSystem.rename(fname, exceptionRequestDirectory + "/" + requestID);
			
			var text = "EXCEPTION: " + Std.string(e) + "\n"
					 + "Stack trace:" + Stack.toString(Stack.exceptionStack()).replace("\n", "\n\t");
					 
			var fout = File.write(exceptionRequestDirectory + "/" + requestID + "-exception.txt");
			fout.writeString(text);
			fout.close();
		}
	}
	
	function processLongRequests()
	{
		var nowTime = Date.now().getTime();
		
		for (file in FileSystem.readDirectory(currentRequestsDirectory))
		{
			var fname = currentRequestsDirectory + "/" + file;
			var stat = FileSystem.stat(fname);
			if (nowTime - stat.mtime.getTime() > maxRequestDuration)
			{
				FileSystem.rename(fname, longRequestsDirectory + "/" + file);
			}			
		}
	}
}