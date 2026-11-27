package orion.multiplayer
{
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.ProgressEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   import flash.utils.Endian;
   import utils.Signal;

   public final class NetworkConnection
   {

      public var packetSignal:Signal = new Signal(NetworkPacket);

      public var closeSignal:Signal = new Signal(NetworkConnection);

      public var errorSignal:Signal = new Signal(String);

      private var _socket:Socket;

      private var _buffer:ByteArray = new ByteArray();

      private var _sequence:uint;

      private var _closed:Boolean;

      public function NetworkConnection(param1:Socket)
      {
         super();
         this._socket = param1;
         this._buffer.endian = Endian.BIG_ENDIAN;
         this.addListeners();
      }

      public function get socket() : Socket
      {
         return this._socket;
      }

      public function get remoteAddress() : String
      {
         try
         {
            if(this._socket != null && "remoteAddress" in this._socket && this._socket.remoteAddress != null)
            {
               return this._socket.remoteAddress;
            }
         }
         catch(e:Error)
         {
         }
         return "";
      }

      public function get connected() : Boolean
      {
         return this._socket != null && this._socket.connected && !this._closed;
      }

      public function send(param1:int, param2:int, param3:ByteArray = null) : void
      {
         var _loc1_:NetworkPacket;
         var _loc2_:ByteArray;
         if(!this.connected)
         {
            return;
         }
         ++this._sequence;
         _loc1_ = new NetworkPacket(param1,param2,this._sequence,param3);
         _loc2_ = _loc1_.encode();
         try
         {
            this._socket.writeBytes(_loc2_,0,_loc2_.length);
            this._socket.flush();
         }
         catch(e:Error)
         {
            errorSignal.dispatch(e.message);
            close();
         }
      }

      public function close() : void
      {
         if(this._closed)
         {
            return;
         }
         this._closed = true;
         this.removeListeners();
         if(this._socket != null)
         {
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
         this.closeSignal.dispatch(this);
      }

      private function addListeners() : void
      {
         this._socket.addEventListener(ProgressEvent.SOCKET_DATA,this.onSocketData);
         this._socket.addEventListener(Event.CLOSE,this.onClose);
         this._socket.addEventListener(IOErrorEvent.IO_ERROR,this.onIOError);
         this._socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
      }

      private function removeListeners() : void
      {
         if(this._socket == null)
         {
            return;
         }
         this._socket.removeEventListener(ProgressEvent.SOCKET_DATA,this.onSocketData);
         this._socket.removeEventListener(Event.CLOSE,this.onClose);
         this._socket.removeEventListener(IOErrorEvent.IO_ERROR,this.onIOError);
         this._socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
      }

      private function onSocketData(param1:ProgressEvent) : void
      {
         if(this._socket.bytesAvailable == 0)
         {
            return;
         }
         this._socket.readBytes(this._buffer,this._buffer.length,this._socket.bytesAvailable);
         this.parsePackets();
      }

      private function parsePackets() : void
      {
         var _loc1_:int = 0;
         var _loc2_:uint = 0;
         var _loc3_:uint = 0;
         var _loc4_:int = 0;
         var _loc5_:int = 0;
         var _loc6_:int = 0;
         var _loc7_:uint = 0;
         var _loc8_:ByteArray = null;
         var _loc9_:NetworkPacket = null;
         this._buffer.position = 0;
         while(this._buffer.bytesAvailable >= MultiplayerProtocol.HEADER_SIZE)
         {
            _loc1_ = int(this._buffer.position);
            _loc2_ = this._buffer.readUnsignedInt();
            if(_loc2_ != MultiplayerProtocol.MAGIC)
            {
               this.errorSignal.dispatch("INVALID_PACKET_MAGIC");
               this.close();
               return;
            }
            _loc3_ = this._buffer.readUnsignedInt();
            _loc4_ = this._buffer.readInt();
            _loc5_ = this._buffer.readInt();
            _loc6_ = this._buffer.readInt();
            _loc7_ = this._buffer.readUnsignedInt();
            if(_loc5_ < 0 || _loc5_ > MultiplayerProtocol.MAX_PAYLOAD)
            {
               this.errorSignal.dispatch("INVALID_PAYLOAD_LENGTH");
               this.close();
               return;
            }
            if(this._buffer.bytesAvailable < _loc5_)
            {
               this._buffer.position = _loc1_;
               break;
            }
            _loc8_ = new ByteArray();
            _loc8_.endian = Endian.BIG_ENDIAN;
            if(_loc5_ > 0)
            {
               this._buffer.readBytes(_loc8_,0,_loc5_);
            }
            _loc8_.position = 0;
            _loc9_ = new NetworkPacket(_loc4_,_loc6_,_loc7_,_loc8_,_loc3_);
            this.packetSignal.dispatch(_loc9_);
         }
         if(this._buffer.position > 0)
         {
            _loc8_ = new ByteArray();
            _loc8_.endian = Endian.BIG_ENDIAN;
            if(this._buffer.bytesAvailable > 0)
            {
               this._buffer.readBytes(_loc8_,0,this._buffer.bytesAvailable);
            }
            this._buffer = _loc8_;
         }
      }

      private function onClose(param1:Event) : void
      {
         this.close();
      }

      private function onIOError(param1:IOErrorEvent) : void
      {
         this.errorSignal.dispatch(param1.text);
         this.close();
      }

      private function onSecurityError(param1:SecurityErrorEvent) : void
      {
         this.errorSignal.dispatch(param1.text);
         this.close();
      }
   }
}
