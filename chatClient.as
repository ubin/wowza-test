var nc:NetConnection = null;
var textchat_so:SharedObject = null;
var lastChatId:Number = 0;
var chatSharedObjectName:String = "textchat";
var chatText:String = "";

function mainInit()
{
	txtUser.text = "me";
	txtMessage.text = "[enter message here]";
	
	//listChat.vScrollPolicy = "auto";
		
	connect.connectStr.text = "rtmp://localhost/textchat";
	connect.soNameStr.text = chatSharedObjectName;

	enablePlayControls(false);
}

function ncOnStatus(infoObject:NetStatusEvent)
{
	trace("nc: "+infoObject.info.code+" ("+infoObject.info.description+")");
	
	if (infoObject.info.code == "NetConnection.Connect.Success")
	{
		initSharedObject(chatSharedObjectName);
	}
	else if (infoObject.info.code == "NetConnection.Connect.Failed")
		prompt.text = "Connection failed: Try rtmp://[server-ip-address]/textchat";
	else if (infoObject.info.code == "NetConnection.Connect.Rejected")
		prompt.text = infoObject.info.description;
}

function doConnect(event:MouseEvent)
{
	if (connect.connectButton.label == "Connect")
	{
		// create a connection to the wowza media server
		nc = new NetConnection();
		
		// trace connection status information
		nc.addEventListener(NetStatusEvent.NET_STATUS, ncOnStatus);
		
		trace("connect: "+connect.connectStr.text);
		chatSharedObjectName = connect.soNameStr.text;
		nc.connect(connect.connectStr.text);
		
		connect.connectButton.label = "Stop";
	}
	else
	{
		nc = null;
		textchat_so = null;
		listChat.htmlText = "";
		chatText = "";
		
		lastChatId = 0;
		
		enablePlayControls(false);
		connect.connectButton.label = "Connect";
	}
}

function enablePlayControls(isEnable:Boolean)
{
	butSend.enabled = isEnable;
	txtMessage.enabled = isEnable;
	txtUser.enabled = isEnable;
	listChat.enabled = isEnable;
}

// format the text chat messages
function formatMessage(chatData:Object)
{
	var msg:String;
	var currTime:Date = chatData.time;
	
	var hour24:Number = currTime.getHours();
	var ampm:String = (hour24<12) ? "AM" : "PM";
	var hourNum:Number = hour24%12;
	if (hourNum == 0)
		hourNum = 12;

	var hourStr:String = hourNum+"";
	var minuteStr:String = (currTime.getMinutes())+"";
	if (minuteStr.length < 2)
		minuteStr = "0"+minuteStr;
	var secondStr:String = (currTime.getSeconds())+"";
	if (secondStr.length < 2)
		secondStr = "0"+secondStr;

	msg = "<u>"+hourStr+":"+minuteStr+":"+secondStr+ampm+"</u> - <b>"+chatData.user+"</b>: "+chatData.message;
	return msg;
}

function syncEventHandler(ev:SyncEvent)
{
	var infoObj:Object = ev.changeList;
	
	// if first time only show last 4 messages in the list
	if (lastChatId == 0)
	{
		lastChatId = Number(textchat_so.data["lastChatId"]) - 4;
		if (lastChatId < 0)
			lastChatId = 0;
	}
	
	// show new messasges
	var currChatId = Number(textchat_so.data["lastChatId"]);
	
	// if there are new messages to display
	if (currChatId > 0)
	{
		var i:Number;
		for(i=(lastChatId+1);i<=currChatId;i++)
		{
			if (textchat_so.data["chatData"+i] != undefined)
			{
				var chatMessage:Object = textchat_so.data["chatData"+i];
				
				var msg:String = formatMessage(chatMessage);
				trace("recvMessage: "+msg);
				//listChat.addItem(msg);
				chatText += "<p>" + msg + "</p>";
				listChat.htmlText = chatText;
			}
		}
		
		if (listChat.length > 0)
			listChat.verticalScrollPosition = listChat.maxVerticalScrollPosition;
		lastChatId = currChatId;
	}
}

function connectSharedObject(soName:String)
{
	enablePlayControls(true);

	textchat_so = SharedObject.getRemote(soName, nc.uri);
	
	// add new message to the chat box as they come in
	textchat_so.addEventListener(SyncEvent.SYNC, syncEventHandler);

	textchat_so.connect(nc);	
}

function connectSharedObjectRes(soName:String)
{
	connectSharedObject(soName);
}

function initSharedObject(soName:String)
{
	// initialize the shared object server side
	nc.call("initSharedObject", new Responder(connectSharedObjectRes), soName);
}

// Add new messages to the chat box by calling the server side function sendMessage
// Additional properties can be added to the chatMessage object if needed.
// They will be passed through the system to the shared object by the server
function addMessage(event:MouseEvent)
{
	var chatMessage:Object = new Object();
	
	chatMessage.message = txtMessage.text;
	chatMessage.time = new Date();
	chatMessage.user = txtUser.text;
	
	trace("sendMessage: "+formatMessage(chatMessage));
	nc.call("addMessage", null, chatSharedObjectName, chatMessage);
}

mainInit();

butSend.addEventListener(MouseEvent.CLICK, addMessage);
connect.connectButton.addEventListener(MouseEvent.CLICK, doConnect);
