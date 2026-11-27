package orion.multiplayer
{
   import flash.utils.ByteArray;
   import flash.utils.Endian;

   public final class NetworkPacket
   {

      public var protocolVersion:uint;

      public var type:int;

      public var senderId:int;

      public var sequence:uint;

      public var payload:ByteArray;

      public function NetworkPacket(param1:int, param2:int, param3:uint, param4:ByteArray = null, param5:uint = 1)
      {
         super();
         this.type = param1;
         this.senderId = param2;
         this.sequence = param3;
         this.protocolVersion = param5;
         this.payload = param4 == null ? new ByteArray() : param4;
         this.payload.endian = Endian.BIG_ENDIAN;
         this.payload.position = 0;
      }

      public function encode() : ByteArray
      {
         var _loc1_:ByteArray = new ByteArray();
         _loc1_.endian = Endian.BIG_ENDIAN;
         _loc1_.writeUnsignedInt(MultiplayerProtocol.MAGIC);
         _loc1_.writeUnsignedInt(this.protocolVersion);
         _loc1_.writeInt(this.type);
         _loc1_.writeInt(this.payload.length);
         _loc1_.writeInt(this.senderId);
         _loc1_.writeUnsignedInt(this.sequence);
         if(this.payload.length > 0)
         {
            _loc1_.writeBytes(this.payload,0,this.payload.length);
         }
         _loc1_.position = 0;
         return _loc1_;
      }
   }
}
