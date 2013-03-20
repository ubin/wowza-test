package com.wowza.wms.plugin.textchat;

import java.util.*;

import com.wowza.wms.application.*;
import com.wowza.wms.amf.*;
import com.wowza.wms.client.*;
import com.wowza.wms.module.*;
import com.wowza.wms.request.*;
import com.wowza.wms.sharedobject.*;

public class ModuleTextChat extends ModuleBase 
{
	private Map<String, ISharedObject> chatSharedOjects = new HashMap<String, ISharedObject>();
	private long nextChatId = 0;
	private long keepCount = 20;
	private int purgeCount = 100;
	
	private ISharedObject getChatSharedObject(String soName, IApplicationInstance appInstance)
	{
		ISharedObject ret = null;
		
		synchronized(chatSharedOjects)
		{
			// get the shared object if it already exists
			ret = chatSharedOjects.get(soName);
			if (ret == null)
			{
				// create a new shared object if it does not exist and initialize it
				getLogger().info("ModuleTextChat.getChatSharedObject: create shared object: "+soName);

				ISharedObjects sharedObjects = appInstance.getSharedObjects();
				ret = new SharedObject(soName);
				sharedObjects.put(soName, ret);
				chatSharedOjects.put(soName, ret);
				
				ret.setProperty("lastChatId", new AMFDataItem(nextChatId));
				ret.acquire();
			}
		}
		
		return ret;
	}
	
	public void initSharedObject(IClient client, RequestFunction function, AMFDataList params)
	{
		// make sure we create the shared object server side so we can initialize it properly
		String soName = params.getString(PARAM1);
		getLogger().info("ModuleTextChat.initSharedObject: init shared object: "+soName);
		ISharedObject textchat_so = getChatSharedObject(soName, client.getAppInstance());
		
		sendResult(client, params, soName);
	}
	
	private void purgeDeleted(ISharedObject textchat_so)
	{
		int purge = textchat_so.getVersion()-purgeCount;
		if (purge > 0)
			textchat_so.purge(purge);
	}
	
	public void clearMessages(IClient client, RequestFunction function, AMFDataList params)
	{
		String soName = params.getString(PARAM1);
		
		while(true)
		{
			ISharedObject textchat_so = getChatSharedObject(soName, client.getAppInstance());
			if (textchat_so == null)
				break;
			
			textchat_so.lock();
			try
			{
				textchat_so.clear();
				purgeDeleted(textchat_so);
			}
			catch(Exception e)
			{
				getLogger().error("ModuleTextChat.clearMessages: "+e.toString());
			}
			finally
			{
				textchat_so.unlock();
			}
			
			break;
		}
	}
	
	// call from client to add a new chat message
	public void addMessage(IClient client, RequestFunction function, AMFDataList params) 
	{
		String soName = params.getString(PARAM1);
		AMFDataObj chatData = params.getObject(PARAM2);
		
		while(true)
		{
			ISharedObject textchat_so = getChatSharedObject(soName, client.getAppInstance());
			if (textchat_so == null)
				break;
			
			textchat_so.lock();
			try
			{
				// add the chat item to the list
				nextChatId++;
				String propName = "chatData"+nextChatId;
				getLogger().info("ModuleTextChat.addMessage: message id: "+propName);
				textchat_so.setProperty(propName, chatData);
				textchat_so.setProperty("lastChatId", new AMFDataItem(nextChatId));
				
				// remove old messages
				if ((nextChatId % keepCount) == 0)
				{
					long startId = nextChatId - keepCount;
					while(startId > 0)
					{
						String delName = "chatData"+startId;
						
						if (textchat_so.getSlot(delName) != null)
							textchat_so.deleteSlot(delName);
						else
							break;
						
						startId--;
					}
					
					purgeDeleted(textchat_so);
				}
			}
			catch(Exception e)
			{
				getLogger().error("ModuleTextChat.addMessage: "+e.toString());
			}
			finally
			{
				textchat_so.unlock();
			}
			
			break;
		}
	}

	public void onAppStop(IApplicationInstance appInstance) 
	{
		synchronized(chatSharedOjects)
		{
			Iterator<String> iter = chatSharedOjects.keySet().iterator();
			while(iter.hasNext())
			{
				String soName = iter.next();
				getLogger().info("ModuleTextChat.onAppStop: release shared object: "+soName);
				ISharedObject textchat_so = chatSharedOjects.get(soName);
				textchat_so.release();
			}
			chatSharedOjects.clear();
		}
	}
}