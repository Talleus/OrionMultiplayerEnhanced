package orion.multiplayer
{
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.TimerEvent;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   import flash.utils.Timer;
   import utils.Signal;

   public final class MultiplayerClient
   {

      public var connectedSignal:Signal = new Signal();

      public var packetSignal:Signal = new Signal(NetworkPacket);

      public var disconnectedSignal:Signal = new Signal();

      public var errorSignal:Signal = new Signal(String);

      private var _socket:Socket;

      private var _connection:NetworkConnection;

      private var _connectTimer:Timer;

      public function MultiplayerClient()
      {
         super();
      }

      public function get connection() : NetworkConnection
      {
         return this._connection;
      }

      public function connect(param1:String, param2:int) : void
      {
         this.disconnect();
         this._socket = new Socket();
         this._socket.addEventListener(Event.CONNECT,this.onConnected);
         this._socket.addEventListener(IOErrorEvent.IO_ERROR,this.onConnectError);
         this._socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
         this._connectTimer = new Timer(8000,1);
         this._connectTimer.addEventListener(TimerEvent.TIMER_COMPLETE,this.onConnectTimeout);
         this._connectTimer.start();
         this._socket.connect(param1,param2);
      }

      public function send(param1:int, param2:int, param3:ByteArray = null) : void
      {
         if(this._connection != null)
         {
            this._connection.send(param1,param2,param3);
         }
      }

      public function disconnect() : void
      {
         var _loc1_:NetworkConnection;
         this.stopConnectTimer();
         if(this._connection != null)
         {
            _loc1_ = this._connection;
            this._connection = null;
            _loc1_.close();
         }
         else if(this._socket != null)
         {
            this.removeSocketListeners();
            try
            {
               if(this._socket.connected)
               {
                  this._socket.close();
               }
            }
            catch(e:Error)
            {
            }
         }
         this._socket = null;
      }

      private function onConnected(param1:Event) : void
      {
         this.stopConnectTimer();
         this.removeSocketListeners();
         this._connection = new NetworkConnection(this._socket);
         this._connection.packetSignal.add(this.onPacket);
         this._connection.closeSignal.add(this.onClosed);
         this._connection.errorSignal.add(this.onConnectionError);
         this.connectedSignal.dispatch();
      }

      private function onPacket(param1:NetworkPacket) : void
      {
         this.packetSignal.dispatch(param1);
      }

      private function onClosed(param1:NetworkConnection) : void
      {
         this._connection = null;
         this.disconnectedSignal.dispatch();
      }

      private function onConnectionError(param1:String) : void
      {
         this.errorSignal.dispatch(param1);
      }

      private function onConnectError(param1:IOErrorEvent) : void
      {
         this.stopConnectTimer();
         this.errorSignal.dispatch(param1.text);
         this.removeSocketListeners();
      }

      private function onSecurityError(param1:SecurityErrorEvent) : void
      {
         this.stopConnectTimer();
         this.errorSignal.dispatch(param1.text);
         this.removeSocketListeners();
      }

      private function onConnectTimeout(param1:TimerEvent) : void
      {
         this.errorSignal.dispatch("CONNECTION TIMEOUT");
         this.disconnect();
      }

      private function stopConnectTimer() : void
      {
         if(this._connectTimer != null)
         {
            this._connectTimer.stop();
            this._connectTimer.removeEventListener(TimerEvent.TIMER_COMPLETE,this.onConnectTimeout);
            this._connectTimer = null;
         }
      }

      private function removeSocketListeners() : void
      {
         if(this._socket == null)
         {
            return;
         }
         this._socket.removeEventListener(Event.CONNECT,this.onConnected);
         this._socket.removeEventListener(IOErrorEvent.IO_ERROR,this.onConnectError);
         this._socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
      }
   }
}
