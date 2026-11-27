package orion.multiplayer
{
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.ServerSocketConnectEvent;
   import flash.net.ServerSocket;
   import flash.utils.ByteArray;
   import utils.Signal;

   public final class MultiplayerServer
   {

      public var connectionSignal:Signal = new Signal(NetworkConnection);

      public var packetSignal:Signal = new Signal(NetworkConnection,NetworkPacket);

      public var disconnectSignal:Signal = new Signal(NetworkConnection);

      public var errorSignal:Signal = new Signal(String);

      private var _server:ServerSocket;

      private var _connections:Vector.<NetworkConnection> = new Vector.<NetworkConnection>();

      private var _port:int;

      public function MultiplayerServer()
      {
         super();
      }

      public function get port() : int
      {
         return this._port;
      }

      public function get running() : Boolean
      {
         return this._server != null && Boolean(this._server.bound);
      }

      public function get connections() : Vector.<NetworkConnection>
      {
         return this._connections;
      }

      public function start(param1:int) : void
      {
         this.stop();
         this._port = param1;
         this._server = new ServerSocket();
         this._server.addEventListener(ServerSocketConnectEvent.CONNECT,this.onConnect);
         this._server.addEventListener(IOErrorEvent.IO_ERROR,this.onError);
         this._server.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
         this._server.bind(param1,"0.0.0.0");
         this._server.listen();
      }

      public function stop() : void
      {
         var _loc1_:int = 0;
         if(this._connections != null)
         {
            _loc1_ = int(this._connections.length - 1);
            while(_loc1_ >= 0)
            {
               this._connections[_loc1_].close();
               _loc1_--;
            }
            this._connections.length = 0;
         }
         if(this._server != null)
         {
            this._server.removeEventListener(ServerSocketConnectEvent.CONNECT,this.onConnect);
            this._server.removeEventListener(IOErrorEvent.IO_ERROR,this.onError);
            this._server.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
            try
            {
               if(this._server.bound)
               {
                  this._server.close();
               }
            }
            catch(e:Error)
            {
            }
            this._server = null;
         }
      }

      public function broadcast(param1:int, param2:int, param3:ByteArray = null, param4:NetworkConnection = null) : void
      {
         var _loc5_:NetworkConnection = null;
         for each(_loc5_ in this._connections)
         {
            if(_loc5_ != param4 && _loc5_.connected)
            {
               _loc5_.send(param1,param2,param3);
            }
         }
      }

      private function onConnect(param1:ServerSocketConnectEvent) : void
      {
         var _loc2_:NetworkConnection = new NetworkConnection(param1.socket);
         this._connections.push(_loc2_);
         _loc2_.packetSignal.add(function(param1:NetworkPacket):void
         {
            packetSignal.dispatch(_loc2_,param1);
         });
         _loc2_.closeSignal.add(this.onConnectionClosed);
         _loc2_.errorSignal.add(function(param1:String):void
         {
            errorSignal.dispatch(param1);
         });
         this.connectionSignal.dispatch(_loc2_);
      }

      private function onConnectionClosed(param1:NetworkConnection) : void
      {
         var _loc2_:int = this._connections.indexOf(param1);
         if(_loc2_ >= 0)
         {
            this._connections.splice(_loc2_,1);
         }
         this.disconnectSignal.dispatch(param1);
      }

      private function onError(param1:IOErrorEvent) : void
      {
         this.errorSignal.dispatch(param1.text);
      }

      private function onSecurityError(param1:SecurityErrorEvent) : void
      {
         this.errorSignal.dispatch(param1.text);
      }
   }
}
