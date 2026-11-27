package orion.multiplayer
{
   public final class MultiplayerProtocol
   {

      public static const MAGIC:uint = 1330793808;

      public static const PROTOCOL_VERSION:uint = 4;

      public static const MOD_VERSION:String = "0.4.5";

      public static const HEADER_SIZE:int = 24;

      public static const MAX_PAYLOAD:int = 32 * 1024 * 1024;

      public static const HELLO:int = 1;

      public static const WELCOME:int = 2;

      public static const REJECT:int = 3;

      public static const WORLD_INIT:int = 4;

      public static const WORLD_READY:int = 5;

      public static const PLAYER_JOIN:int = 6;

      public static const PLAYER_LEAVE:int = 7;

      public static const PLAYER_INPUT:int = 8;

      public static const SNAPSHOT:int = 9;

      public static const CREATURE_SPAWN:int = 10;

      public static const CREATURE_REMOVE:int = 11;

      public static const REQUEST_PLACE_BLOCK:int = 12;

      public static const REQUEST_REMOVE_BLOCK:int = 13;

      public static const REQUEST_PLACE_WALL:int = 14;

      public static const REQUEST_REMOVE_WALL:int = 15;

      public static const TILE_PATCH:int = 16;

      public static const DYNAMIC_WORLD_STATE:int = 17;

      public static const REQUEST_ITEM_PICKUP:int = 18;

      public static const INVENTORY_SYNC:int = 19;

      public static const REQUEST_ATTACK:int = 20;

      public static const PING:int = 21;

      public static const PONG:int = 22;

      public static const HOST_DISCONNECTED:int = 23;

      public static const ERROR:int = 24;

      public static const REQUEST_DROP_ITEM:int = 25;

      public static const REQUEST_INVENTORY_LAYOUT:int = 26;

      public static const REQUEST_CRAFT:int = 27;

      public static const REQUEST_REPAIR:int = 28;

      public static const REQUEST_SHOOT:int = 29;

      public static const PROJECTILE_SPAWN:int = 30;

      public static const REQUEST_CONSUME:int = 31;

      public static const REQUEST_CHEST_LAYOUT:int = 32;

      public static const REQUEST_TREASURE_OPEN:int = 33;

      public static const TREASURE_OPEN_RESULT:int = 34;

      public static const REQUEST_TILE_ACTION:int = 35;

      public static const REQUEST_BEGIN_DESTROY:int = 36;

      public static const CHAT:int = 100;

      public static const PVP_STATE:int = 101;

      public static const ADMIN_XP:int = 102;

      public static const PVP_DEATH:int = 103;

      public static const REQUEST_PVP_STATE:int = 104;

      public static const ADMIN_LEVEL:int = 105;

      public static const RETURN_TO_LOBBY:int = 106;

      public static const TYPING_STATE:int = 107;

      public static const XRAY_STATE:int = 108;

      public static const COMMAND_REQUEST:int = 109;

      public static const OP_STATE:int = 110;

      public static const ADMIN_TELEPORT:int = 111;

      public static const COMMAND_RESULT:int = 112;

      public static const INPUT_UP:int = 1;

      public static const INPUT_DOWN:int = 2;

      public static const INPUT_LEFT:int = 4;

      public static const INPUT_RIGHT:int = 8;

      public static const INPUT_JUMP:int = 16;

      public function MultiplayerProtocol()
      {
         super();
      }
   }
}
