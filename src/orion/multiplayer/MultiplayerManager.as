package orion.multiplayer
{
   import flash.net.InterfaceAddress;
   import flash.net.NetworkInfo;
   import flash.net.NetworkInterface;
   import flash.net.SharedObject;
   import flash.ui.Keyboard;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import flash.utils.getDefinitionByName;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import orion.Core;
   import orion.Experience;
   import orion.Key;
   import orion.inventories.CharacterInventory;
   import orion.worlds.Ability;
   import orion.worlds.Block;
   import orion.worlds.Buff;
   import orion.worlds.BuffEffect;
   import orion.worlds.Ingredient;
   import orion.worlds.Item;
   import orion.worlds.ItemStack;
   import orion.worlds.Knockback;
   import orion.worlds.Recipe;
   import orion.worlds.Tile;
   import orion.worlds.TileEntity;
   import orion.worlds.Wall;
   import orion.worlds.blocks.OreBlock;
   import orion.worlds.entities.CharacterEntity;
   import orion.worlds.entities.CreatureEntity;
   import orion.worlds.entities.ItemEntity;
   import orion.worlds.entities.MobEntity;
   import orion.worlds.entities.PlayerEntity;
   import orion.worlds.entities.ProjectileEntity;
   import orion.worlds.entities.RemotePlayerEntity;
   import orion.worlds.entities.projectiles.*;
   import orion.worlds.items.ArmorItem;
   import orion.worlds.items.BlockItem;
   import orion.worlds.items.BodyArmorItem;
   import orion.worlds.items.ConsumableItem;
   import orion.worlds.items.HeadArmorItem;
   import orion.worlds.items.LegsArmorItem;
   import orion.worlds.items.MiningItem;
   import orion.worlds.items.ProjectileItem;
   import orion.worlds.items.RangedWeaponItem;
   import orion.worlds.items.WallItem;
   import orion.worlds.items.consumable.potions.HealingPotionItem;
   import orion.worlds.items.projectiles.ArrowItem;
   import orion.worlds.items.rweapons.*;
   import orion.worlds.items.tools.HammerItem;
   import orion.worlds.tile_entities.BaseChestTileEntity;
   import orion.worlds.tile_entities.BurnerTileEntity;
   import orion.worlds.tile_entities.FurnaceTileEntity;
   import orion.worlds.tile_entities.RobotPanelTileEntity;
   import orion.worlds.tile_entities.TreasureChestTileEntity;
   import utils.Random;
   import utils.Signal;

   public final class MultiplayerManager
   {

      public static const MODE_OFF:int = 0;

      public static const MODE_HOST:int = 1;

      public static const MODE_CLIENT:int = 2;

      private static const HOST_PLAYER_ID:int = 1;

      private static const PLAYER_INPUT_INTERVAL:int = 33;

      private static const SNAPSHOT_INTERVAL:int = 50;

      private static const PING_INTERVAL:int = 1000;

      private static const DYNAMIC_SYNC_INTERVAL:int = 1000;

      private static const INVENTORY_SYNC_INTERVAL:int = 1000;

      private static const INVENTORY_LAYOUT_DELAY:int = 180;

      private static const PLAYER_RESPAWN_TIME:int = 5000;

      private static const INTERACT_RADIUS:Number = Tile.SIZE * 4.5;

      public var statusSignal:Signal = new Signal(String);

      public var playersChangedSignal:Signal = new Signal(int);

      public var chatSignal:Signal = new Signal(String);

      public var chatInputActive:Boolean = false;

      public var xrayEnabled:Boolean = false;

      public var xrayAllowedPlayers:Dictionary = new Dictionary();

      public var typingPlayers:Dictionary = new Dictionary();

      private var _lastLocalTypingTime:int = 0;

      public var suppressPauseOnce:Boolean = false;

      private var _connectedHost:String = "";

      private var _connectedPort:int = 27015;

      private var _mode:int;

      private var _server:MultiplayerServer;

      private var _client:MultiplayerClient;

      private var _localPlayerId:int;

      private var _nextPlayerId:int = 2;

      private var _nextCreatureId:int = 1000;

      private var _connectionIds:Dictionary = new Dictionary(true);

      private var _idConnections:Dictionary = new Dictionary();

      private var _profiles:Dictionary = new Dictionary();

      private var _remotePlayers:Dictionary = new Dictionary();

      private var _creaturesById:Dictionary = new Dictionary();

      private var _creatureIds:Dictionary = new Dictionary(true);

      private var _lastShootTimes:Dictionary = new Dictionary();

      private var _lastConsumeTimes:Dictionary = new Dictionary();

      private var _lastAttackTimes:Dictionary = new Dictionary();

      private var _destroySessions:Dictionary = new Dictionary();

      private var _gameReady:Boolean;

      private var _pvpPlayers:Dictionary = new Dictionary();

      private var _inputTimer:int;

      private var _snapshotTimer:int;

      private var _pingTimer:int;

      private var _dynamicTimer:int;

      private var _inventorySyncTimer:int;

      private var _inventoryLayoutTimer:int;

      private var _inventoryLayoutDirty:Boolean;

      private var _chestLayoutTimer:int;

      private var _chestLayoutDirty:Boolean;

      private var _dirtyChest:TileEntity;

      private var _dynamicDirty:Boolean;

      private var _stopping:Boolean;

      private var _operatorPlayers:Dictionary = new Dictionary();

      private var _commandActorId:int = 0;

      private var _commandReplyConnection:NetworkConnection;

      private var _lastCommandTimes:Dictionary = new Dictionary();

      private var _blacklist:Array = null;

      private var _lastPvpBlockedNotice:int = 0;

      public function MultiplayerManager()
      {
         super();
      }

      public function sendTyping(isTyping:Boolean) : void
      {
         var now:int = getTimer();
         if(isTyping && now - this._lastLocalTypingTime < 1200)
         {
            return;
         }
         if(isTyping)
         {
            this._lastLocalTypingTime = now;
         }
         var out:ByteArray = new ByteArray();
         out.writeInt(this._localPlayerId);
         out.writeBoolean(isTyping);
         if(this.isHost && this._server != null)
         {
            this._server.broadcast(MultiplayerProtocol.TYPING_STATE,this._localPlayerId,out);
         }
         else if(this.isClient && this._client != null)
         {
            this._client.send(MultiplayerProtocol.TYPING_STATE,this._localPlayerId,out);
         }
      }

      public function getTypingText() : String
      {
         var now:int = getTimer();
         var typers:Array = [];
         for(var idStr in this.typingPlayers)
         {
            var pid:int = int(idStr);
            if(pid != this._localPlayerId && this.typingPlayers[pid] > now)
            {
               var prof:Object = this._profiles[pid];
               var name:String = prof != null && prof.name != null ? String(prof.name) : "#" + pid;
               typers.push(name);
            }
         }
         if(typers.length == 0)
         {
            return "";
         }
         var dotsNum:int = int(now / 350) % 3 + 1;
         var dots:String = dotsNum == 1 ? "." : (dotsNum == 2 ? ".." : "...");
         if(typers.length == 1)
         {
            return typers[0] + " печатает" + dots;
         }
         return typers[0] + " и еще " + (typers.length - 1) + " печатают" + dots;
      }

      public function returnAllToLobby() : void
      {
         if(this.isHost && this._server != null)
         {
            try
            {
               this._server.broadcast(MultiplayerProtocol.RETURN_TO_LOBBY,this._localPlayerId,new ByteArray());
            }
            catch(e:Error)
            {
            }
         }
         this.onReturnToLobby();
      }

      public function onReturnToLobby() : void
      {
         this.detachWorldSignals();
         this._gameReady = false;
         this.chatInputActive = false;
         this.typingPlayers = new Dictionary();
         this.suppressPauseOnce = false;
         this._remotePlayers = new Dictionary();
         this._creaturesById = new Dictionary();
         this._creatureIds = new Dictionary(true);
         this._destroySessions = new Dictionary();
         this._inputTimer = 0;
         this._snapshotTimer = 0;
         this._pingTimer = 0;
         this._dynamicTimer = 0;
         this._inventorySyncTimer = 0;
         this._inventoryLayoutTimer = 0;
         this._inventoryLayoutDirty = false;
         this._chestLayoutTimer = 0;
      }

      public function sendChat(msg:String) : Boolean
      {
         if(msg == null)
         {
            return false;
         }
         msg = msg.replace(/^\s+|\s+$/g,"");
         if(msg.length == 0)
         {
            return false;
         }
         if(msg.charAt(0) == "/")
         {
            this.executeHostCommand(msg);
            return false;
         }
         var out:ByteArray = new ByteArray();
         var prof:Object = this._profiles[this._localPlayerId];
         var nick:String = prof != null && prof.name != null ? prof.name : "Player";
         var fullMsg:String = nick + ": " + msg;
         out.writeUTF(fullMsg);
         if(this._mode == MODE_HOST && this._server != null)
         {
            this._server.broadcast(MultiplayerProtocol.CHAT,0,out,null);
         }
         else if(this._mode == MODE_CLIENT && this._client != null)
         {
            this._client.send(MultiplayerProtocol.CHAT,0,out);
         }
         return true;
      }

      public function isOperator(playerId:int = 0) : Boolean
      {
         if(playerId == 0)
         {
            playerId = this._localPlayerId;
         }
         return playerId == HOST_PLAYER_ID || this._operatorPlayers[playerId] === true;
      }

      private function get commandActorId() : int
      {
         return this._commandActorId > 0 ? this._commandActorId : this._localPlayerId;
      }

      private function handleCommandRequest(connection:NetworkConnection, payload:ByteArray) : void
      {
         var actor:int;
         var now:int;
         var command:String;
         var identity:Object = this._connectionIds[connection];
         if(identity == null || payload == null || payload.length > 1024)
         {
            return;
         }
         actor = int(identity);
         now = getTimer();
         if(this._lastCommandTimes[actor] != null && now - int(this._lastCommandTimes[actor]) < 200)
         {
            return;
         }
         this._lastCommandTimes[actor] = now;
         this._commandActorId = actor;
         this._commandReplyConnection = connection;
         try
         {
            command = payload.readUTF();
            if(command.length > 0 && command.length <= 512 && command.charAt(0) == "/")
            {
               this.executeHostCommand(command);
            }
         }
         catch(commandError:Error)
         {
            this.systemMessage(this.isRussian ? "Не удалось выполнить команду. Проверьте аргументы." : "Command failed. Check its arguments.");
         }
         finally
         {
            this._commandActorId = 0;
            this._commandReplyConnection = null;
         }
      }

      private function sendOperatorState(playerId:int, enabled:Boolean, connection:NetworkConnection = null) : void
      {
         var payload:ByteArray = new ByteArray();
         payload.writeInt(playerId);
         payload.writeBoolean(enabled);
         if(connection != null)
         {
            connection.send(MultiplayerProtocol.OP_STATE,HOST_PLAYER_ID,payload);
         }
         else if(this._server != null)
         {
            this._server.broadcast(MultiplayerProtocol.OP_STATE,HOST_PLAYER_ID,payload);
         }
      }

      private function sendAllOperatorStates(connection:NetworkConnection) : void
      {
         for(var key in this._operatorPlayers)
         {
            if(this._operatorPlayers[key] === true)
            {
               this.sendOperatorState(int(key),true,connection);
            }
         }
      }

      private function executeHostCommand(command:String) : void
      {
         var args:Array = command.split(/\s+/);
         var cmd:String = String(args[0]).toLowerCase();
         if(cmd == "/help")
         {
            this.showCommandHelp(args.length > 1 ? int(args[1]) : 1);
            return;
         }
         if(cmd == "/pvp" && this._commandActorId == 0)
         {
            this.setPvpEnabled(args.length < 2 ? !this.pvpEnabled : this.commandBoolean(String(args[1])));
            return;
         }
         if(this.isClient && cmd == "/xray" && args.length == 1 && !this.isOperator() && this.xrayAllowedPlayers[this._localPlayerId] === true)
         {
            this.xrayEnabled = !this.xrayEnabled;
            this.systemMessage("X-Ray " + (this.xrayEnabled ? "ON" : "OFF"));
            return;
         }
         if(this.isClient)
         {
            if(this._client != null)
            {
               var request:ByteArray = new ByteArray();
               request.writeUTF(command.substr(0,512));
               this._client.send(MultiplayerProtocol.COMMAND_REQUEST,this._localPlayerId,request);
            }
            return;
         }
         var actor:int = this.commandActorId;
         if(!this.isHost || this._profiles[actor] == null)
         {
            return;
         }
         if(cmd == "/list" || cmd == "/ops")
         {
            var names:Array = [];
            for each(var row in this.getPlayerList())
            {
               if(cmd == "/list" || this.isOperator(int(row.id)))
               {
                  names.push("#" + row.id + " " + row.name + (row.isHost ? " [HOST]" : (this.isOperator(int(row.id)) ? " [OP]" : "")));
               }
            }
            this.systemMessage(names.join("; "));
            return;
         }
         if(cmd == "/xray" && args.length == 1 && (this.isOperator(actor) || this.xrayAllowedPlayers[actor] === true))
         {
            this.commandXray(actor,actor == HOST_PLAYER_ID ? !this.xrayEnabled : !Boolean(this.xrayAllowedPlayers[actor]));
            return;
         }
         if(!this.isOperator(actor))
         {
            this.systemMessage(this.isRussian ? "Нужны права оператора. Хост может выдать их: /op <игрок>." : "Operator permission required. The host can use /op <player>.");
            return;
         }
         var hostOnly:Boolean = cmd == "/op" || cmd == "/deop" || cmd == "/admin" || cmd == "/invsee" || cmd == "/item" || cmd == "/clear" || cmd == "/repair";
         if(hostOnly && actor != HOST_PLAYER_ID)
         {
            this.systemMessage(this.isRussian ? "Эта команда доступна только хосту." : "This command is host-only.");
            return;
         }
         if(cmd == "/op" || cmd == "/deop" || cmd == "/admin")
         {
            if(args.length != 2)
            {
               this.systemMessage("/op <id|nick> | /deop <id|nick>");
               return;
            }
            var roleTarget:int = this.resolvePlayerId(String(args[1]));
            if(roleTarget <= 0 || roleTarget == HOST_PLAYER_ID)
            {
               this.systemMessage(this.isRussian ? "Выберите подключённого игрока. Права хоста неизменны." : "Choose a connected player. Host permissions cannot change.");
               return;
            }
            var enabled:Boolean = cmd != "/deop";
            this._operatorPlayers[roleTarget] = enabled;
            this.sendOperatorState(roleTarget,enabled);
            this.playersChangedSignal.dispatch(this.playerCount);
            this.systemMessage((enabled ? "OP + " : "OP - ") + this.playerDisplayName(roleTarget));
            return;
         }
         if(cmd == "/kick" || cmd == "/ban")
         {
            if(args.length < 2)
            {
               this.systemMessage(cmd + " <id|nick> [reason]");
               return;
            }
            if(this.resolvePlayerId(String(args[1])) == HOST_PLAYER_ID)
            {
               this.systemMessage(this.isRussian ? "Хоста нельзя исключить или заблокировать." : "The host cannot be kicked or banned.");
               return;
            }
            if(cmd == "/kick")
            {
               this.commandKick(String(args[1]),args.slice(2).join(" "));
            }
            else
            {
               this.commandBan(String(args[1]),args.slice(2).join(" "));
            }
            return;
         }
         if(cmd == "/unban")
         {
            if(args.length != 2)
            {
               this.systemMessage("/unban <nick|ip>");
               return;
            }
            this.commandUnban(String(args[1]));
            return;
         }
         if(cmd == "/give")
         {
            if(args.length < 3 || args.length > 3 && !this.validCommandInteger(String(args[3]),1,9999))
            {
               this.systemMessage("/give <id|nick> <itemId|name> [1..9999]");
               return;
            }
            this.commandGive(String(args[1]),String(args[2]),args.length > 3 ? int(args[3]) : 1);
            return;
         }
         if(cmd == "/xp")
         {
            if(args.length != 3 || !this.validCommandInteger(String(args[2]),1,100000000))
            {
               this.systemMessage("/xp <id|nick> <1..100000000>");
               return;
            }
            this.commandXp(String(args[1]),int(args[2]));
            return;
         }
         if(cmd == "/level" || cmd == "/lvl")
         {
            if(args.length != 3 || !this.validCommandInteger(String(args[2]),-100000,100000))
            {
               this.systemMessage("/level <id|nick> <level|+N|-N>");
               return;
            }
            this.commandLevel(String(args[1]),String(args[2]));
            return;
         }
         if(cmd == "/xray")
         {
            var xTarget:int = args.length > 1 ? this.resolvePlayerId(String(args[1])) : actor;
            if(xTarget <= 0)
            {
               this.systemMessage(this.isRussian ? "Игрок не найден." : "Player not found.");
               return;
            }
            if(args.length > 2 && !this.validCommandBoolean(String(args[2])))
            {
               this.systemMessage("/xray [id|nick] [on|off]");
               return;
            }
            this.commandXray(xTarget,args.length > 2 ? this.commandBoolean(String(args[2])) : !Boolean(this.xrayAllowedPlayers[xTarget]));
            return;
         }
         if(cmd == "/say")
         {
            if(args.length < 2)
            {
               this.systemMessage("/say <message>");
               return;
            }
            var announcement:String = "[" + (actor == HOST_PLAYER_ID ? "HOST" : "OP " + this.playerDisplayName(actor)) + "] " + args.slice(1).join(" ").substr(0,400);
            var chat:ByteArray = new ByteArray();
            chat.writeUTF(announcement);
            this._server.broadcast(MultiplayerProtocol.CHAT,HOST_PLAYER_ID,chat);
            this.chatSignal.dispatch(announcement);
            return;
         }
         if(!this._gameReady || Context.world == null || Context.game == null)
         {
            this.systemMessage(this.isRussian ? "Сначала запустите мир." : "Start a world first.");
            return;
         }
         if(cmd == "/tp" || cmd == "/teleport" || cmd == "/tphere" || cmd == "/spawn")
         {
            this.commandTeleport(cmd,args);
            return;
         }
         if(cmd == "/time")
         {
            var timeArg:String = args.length == 3 && args[1] == "set" ? String(args[2]).toLowerCase() : (args.length == 2 ? String(args[1]).toLowerCase() : "");
            var hours:Object = {
               "day":6,
               "noon":12,
               "night":18,
               "midnight":0
            };
            var minute:Number = hours[timeArg] != null ? Number(hours[timeArg]) * 60 : Number(timeArg);
            if(timeArg == "" || !isFinite(minute) || minute < 0 || minute >= 1440)
            {
               this.systemMessage("/time set <day|noon|night|midnight|0..1439>");
               return;
            }
            Context.world.setGameTime(int(minute / 60),int(minute % 60));
            this.broadcastSnapshot();
            this.systemMessage("Time: " + int(minute / 60) + ":" + (minute % 60 < 10 ? "0" : "") + int(minute % 60));
            return;
         }
         if(cmd == "/gamerule")
         {
            if(args.length != 3 || !this.validCommandBoolean(String(args[2])))
            {
               this.systemMessage("/gamerule <doDaylightCycle|doMobSpawning> <true|false>");
               return;
            }
            var rule:String = String(args[1]).toLowerCase();
            var flag:Boolean = this.commandBoolean(String(args[2]));
            if(rule == "dodaylightcycle")
            {
               Context.world.gameTimeEnabled = flag;
            }
            else
            {
               if(rule != "domobspawning")
               {
                  this.systemMessage("Rules: doDaylightCycle, doMobSpawning");
                  return;
               }
               Context.world.spawnMobsEnabled = flag;
            }
            this.systemMessage(String(args[1]) + " = " + flag);
            return;
         }
         if(cmd == "/heal" || cmd == "/kill")
         {
            var healthId:int = this.resolvePlayerId(args.length > 1 ? String(args[1]) : "@s");
            if(cmd == "/kill" && healthId == HOST_PLAYER_ID && actor != HOST_PLAYER_ID)
            {
               this.systemMessage(this.isRussian ? "Хост защищён от /kill оператора." : "Operators cannot /kill the host.");
               return;
            }
            var healthPlayer:CharacterEntity = this.commandPlayer(healthId);
            if(healthPlayer == null)
            {
               this.systemMessage(this.isRussian ? "Игрок недоступен." : "Player unavailable.");
               return;
            }
            if(cmd == "/heal" && !healthPlayer.alive)
            {
               this.systemMessage(this.isRussian ? "Дождитесь возрождения игрока." : "Wait for the player to respawn.");
               return;
            }
            healthPlayer.health = cmd == "/heal" ? healthPlayer.maxHealth : 0;
            if(cmd == "/kill")
            {
               healthPlayer.alive = false;
            }
            this.broadcastSnapshot();
            this.systemMessage(cmd + " -> " + this.playerDisplayName(healthId));
            return;
         }
         if(cmd == "/save-all")
         {
            Context.app.saveActiveMultiplayerWorld();
            Context.app.saveCurrentProfile();
            this.systemMessage(this.isRussian ? "Мир и профиль хоста сохранены." : "World and host profile saved.");
            return;
         }
         if(cmd == "/invsee" || cmd == "/item" || cmd == "/clear" || cmd == "/repair")
         {
            this.commandInventory(cmd,args);
            return;
         }
         this.systemMessage(this.isRussian ? "Неизвестная команда. /help 1" : "Unknown command. /help 1");
      }

      private function commandBoolean(value:String) : Boolean
      {
         return ["true","on","1","вкл"].indexOf(value.toLowerCase()) >= 0;
      }

      private function validCommandBoolean(value:String) : Boolean
      {
         return ["true","false","on","off","1","0","вкл","выкл"].indexOf(value.toLowerCase()) >= 0;
      }

      private function validCommandInteger(value:String, minimum:Number, maximum:Number) : Boolean
      {
         var number:Number = Number(value);
         return value.length > 0 && Boolean(isFinite(number)) && number == Math.floor(number) && number >= minimum && number <= maximum;
      }

      private function commandPlayer(playerId:int) : CharacterEntity
      {
         if(Context.world == null)
         {
            return null;
         }
         return playerId == HOST_PLAYER_ID ? Context.world.player : this._remotePlayers[playerId] as CharacterEntity;
      }

      private function commandXray(playerId:int, enabled:Boolean) : void
      {
         this.xrayAllowedPlayers[playerId] = enabled;
         if(playerId == HOST_PLAYER_ID)
         {
            this.xrayEnabled = enabled;
         }
         else
         {
            var connection:NetworkConnection = this._idConnections[playerId] as NetworkConnection;
            if(connection == null)
            {
               this.systemMessage("Player unavailable.");
               return;
            }
            var payload:ByteArray = new ByteArray();
            payload.writeInt(playerId);
            payload.writeBoolean(enabled);
            connection.send(MultiplayerProtocol.XRAY_STATE,HOST_PLAYER_ID,payload);
         }
         this.systemMessage("X-Ray " + (enabled ? "ON" : "OFF") + " -> " + this.playerDisplayName(playerId));
      }

      private function commandTeleport(cmd:String, args:Array) : void
      {
         var subjectId:int = this.commandActorId;
         var destinationId:int = 0;
         var offset:int = 1;
         if(cmd == "/tphere")
         {
            if(args.length != 2)
            {
               this.systemMessage("/tphere <id|nick>");
               return;
            }
            subjectId = this.resolvePlayerId(String(args[1]));
            destinationId = this.commandActorId;
         }
         else if(cmd == "/spawn")
         {
            subjectId = args.length > 1 ? this.resolvePlayerId(String(args[1])) : subjectId;
         }
         else if(args.length == 2)
         {
            destinationId = this.resolvePlayerId(String(args[1]));
         }
         else if(args.length == 3 && !this.isCoordinate(String(args[1])))
         {
            subjectId = this.resolvePlayerId(String(args[1]));
            destinationId = this.resolvePlayerId(String(args[2]));
         }
         else if(args.length == 4)
         {
            subjectId = this.resolvePlayerId(String(args[1]));
            offset = 2;
         }
         else if(args.length != 3)
         {
            this.systemMessage("/tp <player> | /tp [player] <x|~> <y|~> | /tp <player> <target>");
            return;
         }
         var subject:CharacterEntity = this.commandPlayer(subjectId);
         if(subject == null || !subject.alive)
         {
            this.systemMessage(this.isRussian ? "Игрок недоступен." : "Player unavailable.");
            return;
         }
         if(subjectId == HOST_PLAYER_ID && this.commandActorId != HOST_PLAYER_ID)
         {
            this.systemMessage(this.isRussian ? "Оператор не может перемещать хоста." : "Operators cannot move the host.");
            return;
         }
         if(cmd == "/spawn")
         {
            var x:Number = Context.world.spawnPlayerX * Tile.SIZE;
            var y:Number = Context.world.spawnPlayerY * Tile.SIZE + Tile.SIZE * 2 - subject.height;
         }
         else if(destinationId > 0)
         {
            var destination:CharacterEntity = this.commandPlayer(destinationId);
            if(destination == null || !destination.alive)
            {
               this.systemMessage("Target unavailable.");
               return;
            }
            x = destination.position.x;
            y = destination.position.y;
         }
         else
         {
            if(args.length <= offset + 1 || !this.isCoordinate(String(args[offset])) || !this.isCoordinate(String(args[offset + 1])))
            {
               this.systemMessage("Player not found or invalid coordinates.");
               return;
            }
            x = this.commandCoordinate(String(args[offset]),subject.position.x / Tile.SIZE) * Tile.SIZE;
            y = this.commandCoordinate(String(args[offset + 1]),subject.position.y / Tile.SIZE) * Tile.SIZE;
         }
         if(!isFinite(x) || !isFinite(y) || x < 0 || y < 0 || x + subject.width >= Context.world.tilesX * Tile.SIZE || y + subject.height >= Context.world.tilesY * Tile.SIZE)
         {
            this.systemMessage(this.isRussian ? "Координаты за границами мира." : "Coordinates outside the world.");
            return;
         }
         subject.setPosition(x,y);
         subject.velocity.x = 0;
         subject.velocity.y = 0;
         subject.notDamageFromFirstFall();
         if(subjectId != HOST_PLAYER_ID)
         {
            var connection:NetworkConnection = this._idConnections[subjectId] as NetworkConnection;
            if(connection != null)
            {
               var payload:ByteArray = new ByteArray();
               payload.writeDouble(x);
               payload.writeDouble(y);
               connection.send(MultiplayerProtocol.ADMIN_TELEPORT,HOST_PLAYER_ID,payload);
            }
         }
         this.broadcastSnapshot();
         this.systemMessage("TP " + this.playerDisplayName(subjectId) + " -> " + int(x / Tile.SIZE) + ", " + int(y / Tile.SIZE));
      }

      private function isCoordinate(value:String) : Boolean
      {
         return /^~(?:[+-]?\d+(?:\.\d+)?)?$/.test(value) || /^[+-]?\d+(?:\.\d+)?$/.test(value);
      }

      private function commandCoordinate(value:String, origin:Number) : Number
      {
         return value.charAt(0) == "~" ? origin + (value.length > 1 ? Number(value.substr(1)) : 0) : Number(value);
      }

      private function commandInventory(cmd:String, args:Array) : void
      {
         var targetId:int = this.resolvePlayerId(args.length > 1 ? String(args[1]) : "@s");
         var inventory:CharacterInventory = this.inventoryForPlayer(targetId);
         if(inventory == null)
         {
            this.systemMessage(this.isRussian ? "Инвентарь недоступен." : "Inventory unavailable.");
            return;
         }
         var groups:Array = [inventory.items,inventory.armors,inventory.socialArmors,inventory.projectiles];
         var labels:Array = ["slot","armor","social","ammo"];
         if(cmd == "/invsee")
         {
            var entries:Array = [];
            var group:int = 0;
            while(group < groups.length)
            {
               var i:int = 0;
               while(i < groups[group].length)
               {
                  var stack:ItemStack = groups[group][i];
                  if(stack != null && stack.item != null)
                  {
                     entries.push(labels[group] + " " + (i + 1) + ": " + stack.item.id + " " + this.itemDisplayName(stack.item) + " x" + stack.count);
                  }
                  i++;
               }
               group++;
            }
            var page:int = args.length > 2 ? Math.max(1,int(args[2])) : 1;
            this.systemMessage("Inventory " + this.playerDisplayName(targetId) + " " + page + "/" + Math.max(1,Math.ceil(entries.length / 5)));
            i = (page - 1) * 5;
            while(i < Math.min(entries.length,page * 5))
            {
               this.systemMessage(String(entries[i]));
               i++;
            }
            return;
         }
         if(cmd == "/item")
         {
            if(args.length < 4 || !this.validCommandInteger(String(args[2]),1,inventory.items.length) || args.length > 4 && !this.validCommandInteger(String(args[4]),1,9999))
            {
               this.systemMessage("/item <player> <slot 1..45> <itemId|air> [count]");
               return;
            }
            i = int(args[2]) - 1;
            if(args[3] == "air" || args[3] == "0")
            {
               inventory.items[i] = null;
            }
            else
            {
               var item:Item = this.resolveItem(String(args[3]));
               if(item == null)
               {
                  this.systemMessage("Item not found.");
                  return;
               }
               stack = new ItemStack(item,0,Math.min(Math.max(1,item.maxStackSize),args.length > 4 ? int(args[4]) : 1));
               if(item.destroyable)
               {
                  stack.durability = item.durability;
               }
               inventory.items[i] = stack;
            }
         }
         else if(cmd == "/clear" || cmd == "/repair")
         {
            var selectedItem:Item = null;
            if(cmd == "/clear" && args.length > 2)
            {
               selectedItem = this.resolveItem(String(args[2]));
               if(selectedItem == null)
               {
                  this.systemMessage("Item not found.");
                  return;
               }
            }
            group = 0;
            while(group < groups.length)
            {
               i = 0;
               while(i < groups[group].length)
               {
                  stack = groups[group][i];
                  if(!(stack == null || stack.item == null))
                  {
                     if(cmd == "/clear" && (selectedItem == null || stack.item == selectedItem))
                     {
                        groups[group][i] = null;
                     }
                     else if(cmd == "/repair" && stack.item.destroyable)
                     {
                        stack.durability = stack.item.durability;
                     }
                  }
                  i++;
               }
               group++;
            }
         }
         this.sendInventorySync(targetId);
         if(targetId == HOST_PLAYER_ID)
         {
            Context.app.saveCurrentProfile();
         }
         this.systemMessage(cmd + " -> " + this.playerDisplayName(targetId));
      }

      private function showCommandHelp(page:int) : void
      {
         if(page < 1 || page > 4)
         {
            page = 1;
         }
         this.systemMessage((this.isRussian ? "Команды " : "Commands ") + page + "/4 — /help <1..4>");
         if(page == 1)
         {
            this.systemMessage("/list | /ops | /pvp [on|off]");
            this.systemMessage("/give <player> <itemId> [count] | /xp <player> <amount>");
            this.systemMessage("/level <player> <level|+N|-N> | /heal [player]");
            this.systemMessage("/xray [player] [on|off] | /say <message>");
         }
         else if(page == 2)
         {
            this.systemMessage("/tp <target> | /tp [player] <x|~> <y|~>");
            this.systemMessage("/tp <player> <target> | /tphere <player> | /spawn [player]");
            this.systemMessage("/time set <day|noon|night|midnight|0..1439>");
            this.systemMessage("/gamerule <doDaylightCycle|doMobSpawning> <true|false>");
            this.systemMessage("/save-all | /kill [player]");
         }
         else if(page == 3)
         {
            this.systemMessage("/op <player> | /deop <player> (HOST)");
            this.systemMessage("/kick <player> [reason] | /ban <player> [reason]");
            this.systemMessage("/unban <nick|ip>");
            this.systemMessage(this.isRussian ? "ОП не может перемещать, убить, кикнуть или забанить хоста." : "OP cannot move, kill, kick or ban the host.");
         }
         else
         {
            this.systemMessage(this.isRussian ? "Только хост — управление инвентарём:" : "HOST only — inventory editing:");
            this.systemMessage("/invsee <player> [page]");
            this.systemMessage("/item <player> <slot 1..45> <itemId|air> [count]");
            this.systemMessage("/clear [player] [itemId] | /repair [player]");
         }
         this.systemMessage(this.isRussian ? "Цель: id, ник, me или @s. Права ОП действуют до отключения." : "Target: id, nickname, me or @s. OP lasts until disconnect.");
      }

      private function commandKick(param1:String, param2:String) : void
      {
         var _loc3_:int = this.resolvePlayerId(param1);
         if(_loc3_ <= 0)
         {
            this.systemMessage(this.isRussian ? "Игрок не найден." : "Player not found.");
            return;
         }
         if(_loc3_ == HOST_PLAYER_ID)
         {
            this.systemMessage(this.isRussian ? "Хост не может выгнать себя." : "The host cannot kick itself.");
            return;
         }
         var _loc4_:NetworkConnection = this._idConnections[_loc3_] as NetworkConnection;
         if(_loc4_ == null)
         {
            this.systemMessage(this.isRussian ? "Игрок уже отключён." : "Player is already disconnected.");
            return;
         }
         var _loc5_:ByteArray = new ByteArray();
         _loc5_.writeUTF("KICKED BY HOST" + (param2.length > 0 ? ": " + param2 : ""));
         _loc4_.send(MultiplayerProtocol.REJECT,HOST_PLAYER_ID,_loc5_);
         this.systemMessage((this.isRussian ? "Игрок исключён: " : "Kicked: ") + this.playerDisplayName(_loc3_));
         _loc4_.close();
      }

      public function banPlayer(param1:int, param2:String = "") : void
      {
         this.commandBan(String(param1),param2);
      }

      private function commandBan(param1:String, param2:String = "") : void
      {
         var _loc3_:int = this.resolvePlayerId(param1);
         if(_loc3_ <= 0)
         {
            this.systemMessage(this.isRussian ? "Игрок не найден." : "Player not found.");
            return;
         }
         if(_loc3_ == HOST_PLAYER_ID)
         {
            this.systemMessage(this.isRussian ? "Хост не может забанить себя." : "The host cannot ban itself.");
            return;
         }
         var _loc4_:NetworkConnection = this._idConnections[_loc3_] as NetworkConnection;
         var prof:Object = this._profiles[_loc3_];
         var pName:String = prof != null && prof.name != null ? String(prof.name) : this.playerDisplayName(_loc3_);
         var pIp:String = _loc4_ != null ? _loc4_.remoteAddress : "";
         this.addBan(pName,pIp,param2);
         if(_loc4_ != null)
         {
            var _loc5_:ByteArray = new ByteArray();
            _loc5_.writeUTF("BANNED BY HOST" + (param2.length > 0 ? ": " + param2 : ""));
            _loc4_.send(MultiplayerProtocol.REJECT,HOST_PLAYER_ID,_loc5_);
            _loc4_.close();
         }
         this.systemMessage((this.isRussian ? "Игрок заблокирован: " : "Banned: ") + pName + (pIp.length > 0 ? " [" + pIp + "]" : ""));
         this.playersChangedSignal.dispatch(this.playerCount);
      }

      private function commandUnban(param1:String) : void
      {
         if(this._blacklist == null)
         {
            this.loadBlacklist();
         }
         var clean:String = param1 != null ? param1.toLowerCase() : "";
         var removed:Boolean = false;
         var i:int = this._blacklist.length - 1;
         while(i >= 0)
         {
            var b:Object = this._blacklist[i];
            if(b != null)
            {
               if(b.nick != null && String(b.nick).toLowerCase() == clean || b.ip != null && String(b.ip).toLowerCase() == clean)
               {
                  this._blacklist.splice(i,1);
                  removed = true;
               }
            }
            i--;
         }
         if(removed)
         {
            this.saveBlacklist();
            this.systemMessage((this.isRussian ? "Разблокирован: " : "Unbanned: ") + param1);
         }
         else
         {
            this.systemMessage((this.isRussian ? "Запись не найдена в чёрном списке: " : "Not found in blacklist: ") + param1);
         }
      }

      public function getBlacklist() : Array
      {
         if(this._blacklist == null)
         {
            this.loadBlacklist();
         }
         return this._blacklist;
      }

      public function addBan(nick:String, ip:String, reason:String = "") : void
      {
         if(this._blacklist == null)
         {
            this.loadBlacklist();
         }
         var cleanNick:String = nick != null ? nick : "";
         var cleanIp:String = ip != null ? ip : "";
         if(cleanNick.length == 0 && cleanIp.length == 0)
         {
            return;
         }
         for each(var b in this._blacklist)
         {
            if(b != null)
            {
               if(cleanNick.length > 0 && b.nick != null && String(b.nick).toLowerCase() == cleanNick.toLowerCase())
               {
                  if(cleanIp.length > 0 && (b.ip == null || String(b.ip).length == 0))
                  {
                     b.ip = cleanIp;
                     this.saveBlacklist();
                  }
                  return;
               }
               if(cleanIp.length > 0 && b.ip != null && String(b.ip).toLowerCase() == cleanIp.toLowerCase())
               {
                  if(cleanNick.length > 0 && (b.nick == null || String(b.nick).length == 0))
                  {
                     b.nick = cleanNick;
                     this.saveBlacklist();
                  }
                  return;
               }
            }
         }
         var d:Date = new Date();
         var minStr:String = d.minutes < 10 ? "0" + d.minutes : String(d.minutes);
         var dateStr:String = d.fullYear + "-" + (d.month + 1) + "-" + d.date + " " + d.hours + ":" + minStr;
         var entry:Object = {
            "nick":cleanNick,
            "ip":cleanIp,
            "reason":reason,
            "date":dateStr
         };
         this._blacklist.push(entry);
         this.saveBlacklist();
      }

      public function removeBanByIndex(index:int) : void
      {
         if(this._blacklist == null)
         {
            this.loadBlacklist();
         }
         if(index >= 0 && index < this._blacklist.length)
         {
            this._blacklist.splice(index,1);
            this.saveBlacklist();
         }
      }

      public function isBanned(nick:String, ip:String) : Boolean
      {
         if(this._blacklist == null)
         {
            this.loadBlacklist();
         }
         var cleanNick:String = nick != null ? nick.toLowerCase() : "";
         var cleanIp:String = ip != null ? ip.toLowerCase() : "";
         for each(var b in this._blacklist)
         {
            if(b != null)
            {
               if(cleanNick.length > 0 && b.nick != null && String(b.nick).toLowerCase() == cleanNick)
               {
                  return true;
               }
               if(cleanIp.length > 0 && b.ip != null && String(b.ip).toLowerCase() == cleanIp)
               {
                  return true;
               }
            }
         }
         return false;
      }

      private function loadBlacklist() : void
      {
         var so:SharedObject;
         try
         {
            so = SharedObject.getLocal("orion_blacklist");
            if(so.data.bans != null && so.data.bans is Array)
            {
               this._blacklist = so.data.bans as Array;
            }
            else
            {
               this._blacklist = [];
            }
         }
         catch(e:Error)
         {
            this._blacklist = [];
         }
      }

      private function saveBlacklist() : void
      {
         var so:SharedObject;
         try
         {
            so = SharedObject.getLocal("orion_blacklist");
            so.data.bans = this._blacklist;
            so.flush();
         }
         catch(e:Error)
         {
         }
      }

      private function commandGive(param1:String, param2:String, param3:int) : void
      {
         if(!this._gameReady || Context.game == null)
         {
            this.systemMessage(this.isRussian ? "Команда /give доступна после запуска игры." : "/give is available after the game starts.");
            return;
         }
         var _loc4_:int = this.resolvePlayerId(param1);
         var _loc5_:Item = this.resolveItem(param2);
         if(_loc4_ <= 0)
         {
            this.systemMessage(this.isRussian ? "Игрок не найден." : "Player not found.");
            return;
         }
         if(_loc5_ == null)
         {
            this.systemMessage(this.isRussian ? "Предмет не найден. Используйте ID предмета." : "Item not found. Use an item ID.");
            return;
         }
         if(param3 <= 0)
         {
            this.systemMessage(this.isRussian ? "Количество должно быть больше нуля." : "Count must be greater than zero.");
            return;
         }
         param3 = Math.min(param3,9999);
         var _loc6_:CharacterInventory = this.inventoryForPlayer(_loc4_);
         if(_loc6_ == null)
         {
            this.systemMessage(this.isRussian ? "Инвентарь игрока недоступен." : "Player inventory is unavailable.");
            return;
         }
         var _loc7_:int = 0;
         var _loc8_:int = Math.max(1,_loc5_.maxStackSize);
         while(_loc7_ < param3)
         {
            var _loc9_:int = Math.min(_loc8_,param3 - _loc7_);
            var _loc10_:ItemStack = new ItemStack(_loc5_,0,_loc9_);
            if(_loc5_.destroyable)
            {
               _loc10_.durability = _loc5_.durability;
            }
            if(!_loc6_.canAdd(_loc10_))
            {
               break;
            }
            _loc6_.add(_loc10_);
            _loc7_ += _loc9_;
         }
         if(_loc7_ == 0)
         {
            this.systemMessage(this.isRussian ? "В инвентаре нет места." : "There is no inventory space.");
            return;
         }
         this.sendInventorySync(_loc4_);
         this.systemMessage((this.isRussian ? "Выдано: " : "Given: ") + _loc7_ + " x " + this.itemDisplayName(_loc5_) + " -> " + this.playerDisplayName(_loc4_));
      }

      private function commandXp(param1:String, param2:int) : void
      {
         if(!this._gameReady || Context.world == null)
         {
            this.systemMessage(this.isRussian ? "Команда /xp доступна после запуска игры." : "/xp is available after the game starts.");
            return;
         }
         var _loc3_:int = this.resolvePlayerId(param1);
         if(_loc3_ <= 0)
         {
            this.systemMessage(this.isRussian ? "Игрок не найден." : "Player not found.");
            return;
         }
         if(param2 <= 0)
         {
            this.systemMessage(this.isRussian ? "Количество опыта должно быть больше нуля." : "XP amount must be greater than zero.");
            return;
         }
         param2 = Math.min(param2,100000000);
         if(_loc3_ == HOST_PLAYER_ID)
         {
            Context.world.player.addExperience(param2);
         }
         else
         {
            var _loc4_:NetworkConnection = this._idConnections[_loc3_] as NetworkConnection;
            var _loc5_:RemotePlayerEntity = this._remotePlayers[_loc3_] as RemotePlayerEntity;
            if(_loc4_ == null || _loc5_ == null)
            {
               this.systemMessage(this.isRussian ? "Игрок недоступен." : "Player is unavailable.");
               return;
            }
            var _loc6_:Object = this._profiles[_loc3_];
            if(_loc6_ != null)
            {
               _loc6_.experience = Experience.correctExperience(int(_loc6_.experience) + param2);
               _loc6_.level = Experience.experienceToLevel(int(_loc6_.experience));
               _loc5_.level = int(_loc6_.level);
            }
            var _loc7_:ByteArray = new ByteArray();
            _loc7_.writeInt(param2);
            _loc4_.send(MultiplayerProtocol.ADMIN_XP,HOST_PLAYER_ID,_loc7_);
         }
         this.systemMessage((this.isRussian ? "Выдан опыт: " : "XP granted: ") + param2 + " -> " + this.playerDisplayName(_loc3_));
      }

      private function commandLevel(param1:String, param2:String) : void
      {
         if(!this._gameReady || Context.world == null)
         {
            this.systemMessage(this.isRussian ? "Команда /level доступна после запуска игры." : "/level is available after the game starts.");
            return;
         }
         var _loc3_:int = this.resolvePlayerId(param1);
         if(_loc3_ <= 0)
         {
            this.systemMessage(this.isRussian ? "Игрок не найден." : "Player not found.");
            return;
         }
         if(param2 == null || param2.length == 0 || isNaN(Number(param2)))
         {
            this.systemMessage(this.isRussian ? "Укажите уровень числом, например 20, +5 или -3." : "Enter a level, for example 20, +5 or -3.");
            return;
         }
         if(_loc3_ == HOST_PLAYER_ID)
         {
            var _loc4_:int = Context.world.player.level;
         }
         else
         {
            var _loc5_:Object = this._profiles[_loc3_];
            _loc4_ = _loc5_ != null && _loc5_.level != null ? int(_loc5_.level) : 1;
         }
         var _loc6_:int = int(Number(param2));
         var _loc7_:int = param2.charAt(0) == "+" || param2.charAt(0) == "-" ? _loc4_ + _loc6_ : _loc6_;
         _loc7_ = Math.max(Experience.MIN_LEVEL,Math.min(Experience.MAX_LEVEL,_loc7_));
         var _loc8_:int = Experience.levelToExperience(_loc7_);
         if(_loc3_ == HOST_PLAYER_ID)
         {
            Context.world.player.experience = _loc8_;
            Context.app.saveCurrentProfile();
         }
         else
         {
            var _loc9_:NetworkConnection = this._idConnections[_loc3_] as NetworkConnection;
            var _loc10_:RemotePlayerEntity = this._remotePlayers[_loc3_] as RemotePlayerEntity;
            if(_loc9_ == null || _loc10_ == null)
            {
               this.systemMessage(this.isRussian ? "Игрок недоступен." : "Player is unavailable.");
               return;
            }
            _loc5_ = this._profiles[_loc3_];
            if(_loc5_ != null)
            {
               _loc5_.experience = _loc8_;
               _loc5_.level = _loc7_;
            }
            _loc10_.level = _loc7_;
            var _loc11_:ByteArray = new ByteArray();
            _loc11_.writeInt(_loc8_);
            _loc9_.send(MultiplayerProtocol.ADMIN_LEVEL,HOST_PLAYER_ID,_loc11_);
         }
         this.systemMessage((this.isRussian ? "Уровень установлен: " : "Level set: ") + _loc7_ + " -> " + this.playerDisplayName(_loc3_));
      }

      private function resolvePlayerId(param1:String) : int
      {
         var _loc2_:Number = Number(param1);
         if(!isNaN(_loc2_) && this._profiles[int(_loc2_)] != null)
         {
            return int(_loc2_);
         }
         var _loc3_:String = param1.toLowerCase();
         if(_loc3_ == "me" || _loc3_ == "@s")
         {
            return this.commandActorId;
         }
         var _loc4_:Object = null;
         var _loc5_:Object = null;
         for(_loc4_ in this._profiles)
         {
            _loc5_ = this._profiles[_loc4_];
            if(_loc5_ != null && _loc5_.name != null && String(_loc5_.name).toLowerCase() == _loc3_)
            {
               return int(_loc4_);
            }
         }
         return -1;
      }

      private function resolveItem(param1:String) : Item
      {
         var _loc2_:Number = Number(param1);
         if(!isNaN(_loc2_) && int(_loc2_) >= 0 && int(_loc2_) < Item.ITEMS.length)
         {
            return Item.ITEMS[int(_loc2_)];
         }
         var _loc3_:String = this.normalizeName(param1);
         var _loc4_:Item = null;
         var _loc5_:int = 0;
         while(_loc5_ < Item.ITEMS.length)
         {
            _loc4_ = Item.ITEMS[_loc5_];
            if(_loc4_ != null && (this.normalizeName(_loc4_.name) == _loc3_ || this.normalizeName(_loc4_.nameId) == _loc3_ || this.normalizeName(_loc4_.nameKey) == _loc3_ || this.normalizeName(_loc4_.nameId) == "item_" + _loc3_ || this.normalizeName(_loc4_.nameKey) == "item_" + _loc3_ || this.normalizeName(_loc4_.nameId) == "block_" + _loc3_ || this.normalizeName(_loc4_.nameKey) == "block_" + _loc3_))
            {
               return _loc4_;
            }
            _loc5_++;
         }
         return null;
      }

      private function normalizeName(param1:String) : String
      {
         return param1 == null ? "" : param1.toLowerCase().replace(/[\s\-]+/g,"_");
      }

      private function inventoryForPlayer(param1:int) : CharacterInventory
      {
         if(param1 == HOST_PLAYER_ID)
         {
            return Context.game == null ? null : Context.game.inventory;
         }
         var _loc2_:RemotePlayerEntity = this._remotePlayers[param1] as RemotePlayerEntity;
         return _loc2_ == null ? null : _loc2_.inventory;
      }

      private function playerDisplayName(param1:int) : String
      {
         var _loc2_:Object = this._profiles[param1];
         return (_loc2_ != null && _loc2_.name != null ? String(_loc2_.name) : "Player") + " (#" + param1 + ")";
      }

      private function itemDisplayName(param1:Item) : String
      {
         return param1.name != null && param1.name.length > 0 ? param1.name : "item #" + param1.id;
      }

      private function getSystemPrefix() : String
      {
         var lang:String = Context.app != null && Context.app._choosedLanguage != null ? Context.app._choosedLanguage : "en";
         if(lang == "ru")
         {
            return "[Система] ";
         }
         if(lang == "fr")
         {
            return "[Système] ";
         }
         if(lang == "es")
         {
            return "[Sistema] ";
         }
         if(lang == "vi")
         {
            return "[Hệ thống] ";
         }
         if(lang == "ti")
         {
            return "[ระบบ] ";
         }
         if(lang == "zh")
         {
            return "[系统] ";
         }
         return "[System] ";
      }

      private function getBannedRejectedText() : String
      {
         var lang:String = Context.app != null && Context.app._choosedLanguage != null ? Context.app._choosedLanguage : "en";
         if(lang == "ru")
         {
            return "Заблокированный игрок отклонён: ";
         }
         if(lang == "fr")
         {
            return "Joueur banni rejeté : ";
         }
         if(lang == "es")
         {
            return "Jugador bloqueado rechazado: ";
         }
         if(lang == "vi")
         {
            return "Đã từ chối người chơi bị cấm: ";
         }
         if(lang == "ti")
         {
            return "ปฏิเสธผู้เล่นที่ถูกแบน: ";
         }
         if(lang == "zh")
         {
            return "已拒绝被封禁的玩家: ";
         }
         return "Banned player rejected: ";
      }

      private function systemMessage(param1:String) : void
      {
         if(this._commandReplyConnection != null)
         {
            var reply:ByteArray = new ByteArray();
            reply.writeUTF(this.getSystemPrefix() + param1);
            this._commandReplyConnection.send(MultiplayerProtocol.COMMAND_RESULT,HOST_PLAYER_ID,reply);
            return;
         }
         this.chatSignal.dispatch(this.getSystemPrefix() + param1);
      }

      private function get isRussian() : Boolean
      {
         return Context.app != null && Context.app._choosedLanguage == "ru";
      }

      public function get localNickname() : String
      {
         var prof:Object = this._profiles[this._localPlayerId];
         var nick:String = prof != null && prof.name != null ? String(prof.name).replace(/^\s+|\s+$/g,"") : "";
         return nick.length > 0 ? nick : "Player";
      }

      public function get mode() : int
      {
         return this._mode;
      }

      public function get active() : Boolean
      {
         return this._mode != MODE_OFF;
      }

      public function get isHost() : Boolean
      {
         return this._mode == MODE_HOST;
      }

      public function get isClient() : Boolean
      {
         return this._mode == MODE_CLIENT;
      }

      public function get localPlayerId() : int
      {
         return this._localPlayerId;
      }

      public function get pvpEnabled() : Boolean
      {
         return this.playerPvpEnabled(this._localPlayerId);
      }

      public function setPvpEnabled(param1:Boolean) : void
      {
         if(!this.active || this._localPlayerId <= 0)
         {
            return;
         }
         this._pvpPlayers[this._localPlayerId] = param1;
         if(this.isHost)
         {
            this.broadcastPvpState(this._localPlayerId,param1);
         }
         else if(this._client != null)
         {
            var _loc2_:ByteArray = new ByteArray();
            _loc2_.writeBoolean(param1);
            this._client.send(MultiplayerProtocol.REQUEST_PVP_STATE,this._localPlayerId,_loc2_);
         }
         this.systemMessage(this.isRussian ? "PvP " + (param1 ? "включён." : "выключен.") : "PvP " + (param1 ? "enabled." : "disabled."));
      }

      public function playerPvpEnabled(param1:int) : Boolean
      {
         return param1 > 0 && this._pvpPlayers[param1] === true;
      }

      public function isPvpPlayerAttack(param1:CreatureEntity, param2:CreatureEntity) : Boolean
      {
         if(!this.isNetworkPlayer(param1) || !this.isNetworkPlayer(param2) || param1 == param2)
         {
            return false;
         }
         var id1:int = this.playerIdForEntity(param1);
         var id2:int = this.playerIdForEntity(param2);
         return this.playerPvpEnabled(id1) && this.playerPvpEnabled(id2);
      }

      public function canProjectileHit(param1:CreatureEntity, param2:CreatureEntity) : Boolean
      {
         if(param1 == null)
         {
            return true;
         }
         if(this.isNetworkPlayer(param1) && this.isNetworkPlayer(param2))
         {
            return this.isPvpPlayerAttack(param1,param2);
         }
         return param1.isEnemy(param2);
      }

      public function onPlayerDamagedByPlayer(param1:CreatureEntity, param2:CreatureEntity, param3:Boolean) : void
      {
         if(!this.isHost || !param3 || param1 == null || param1.alive || !this.isPvpPlayerAttack(param2,param1))
         {
            return;
         }
         var _loc4_:int = param1 is RemotePlayerEntity ? RemotePlayerEntity(param1).networkPlayerId : HOST_PLAYER_ID;
         if(_loc4_ == HOST_PLAYER_ID && Context.world != null)
         {
            Context.world.player["suppressNextDeathExperienceLoss"] = true;
         }
         else
         {
            var _loc5_:NetworkConnection = this._idConnections[_loc4_] as NetworkConnection;
            if(_loc5_ != null)
            {
               _loc5_.send(MultiplayerProtocol.PVP_DEATH,HOST_PLAYER_ID);
            }
         }
      }

      private function isNetworkPlayer(param1:CreatureEntity) : Boolean
      {
         return param1 is PlayerEntity || param1 is RemotePlayerEntity;
      }

      private function playerIdForEntity(param1:CreatureEntity) : int
      {
         if(param1 is RemotePlayerEntity)
         {
            return RemotePlayerEntity(param1).networkPlayerId;
         }
         return param1 is PlayerEntity ? this._localPlayerId : 0;
      }

      private function broadcastPvpState(param1:int, param2:Boolean, param3:NetworkConnection = null) : void
      {
         if(this._server == null)
         {
            return;
         }
         var _loc4_:ByteArray = new ByteArray();
         _loc4_.writeInt(param1);
         _loc4_.writeBoolean(param2);
         if(param3 != null)
         {
            param3.send(MultiplayerProtocol.PVP_STATE,HOST_PLAYER_ID,_loc4_);
         }
         else
         {
            this._server.broadcast(MultiplayerProtocol.PVP_STATE,HOST_PLAYER_ID,_loc4_);
         }
      }

      private function sendAllPvpStates(param1:NetworkConnection) : void
      {
         var _loc2_:Object = null;
         var _loc3_:int = 0;
         for(_loc2_ in this._profiles)
         {
            _loc3_ = int(_loc2_);
            this.broadcastPvpState(_loc3_,this.playerPvpEnabled(_loc3_),param1);
         }
      }

      public function get playerCount() : int
      {
         var _loc1_:int = 0;
         var _loc2_:Object = null;
         if(!this.active)
         {
            return 0;
         }
         for(_loc2_ in this._profiles)
         {
            _loc1_++;
         }
         return _loc1_ > 0 ? _loc1_ : 1;
      }

      public function getPlayerList() : Array
      {
         var list:Array = [];
         if(!this.active)
         {
            return list;
         }
         var ids:Array = [];
         for(var k in this._profiles)
         {
            ids.push(int(k));
         }
         ids.sort(Array.NUMERIC);
         for each(var pid in ids)
         {
            var prof:Object = this._profiles[pid];
            var pName:String = prof != null && prof.name != null && String(prof.name).length > 0 ? String(prof.name) : (pid == HOST_PLAYER_ID ? "Host" : "Player " + pid);
            list.push({
               "id":pid,
               "name":pName,
               "isHost":pid == HOST_PLAYER_ID,
               "isOperator":this.isOperator(pid),
               "isMe":pid == this._localPlayerId
            });
         }
         return list;
      }

      public function kickPlayer(param1:int, param2:String = "") : void
      {
         this.commandKick(String(param1),param2);
      }

      public function get connectedHost() : String
      {
         return this._connectedHost;
      }

      public function get connectedPort() : int
      {
         return this._connectedPort;
      }

      public function startHost(param1:int) : Boolean
      {
         this.stop();
         this._mode = MODE_HOST;
         this._localPlayerId = HOST_PLAYER_ID;
         this._profiles[HOST_PLAYER_ID] = this.getLocalProfile();
         this._pvpPlayers[HOST_PLAYER_ID] = false;
         this._server = new MultiplayerServer();
         this._server.connectionSignal.add(this.onServerConnection);
         this._server.packetSignal.add(this.onServerPacket);
         this._server.disconnectSignal.add(this.onServerDisconnect);
         this._server.errorSignal.add(this.onNetworkError);
         try
         {
            this._server.start(param1);
         }
         catch(e:Error)
         {
            setStatus("SERVER ERROR: " + e.message);
            stop();
            return false;
         }
         this.setStatus("SERVER RUNNING :" + param1);
         this.playersChangedSignal.dispatch(this.playerCount);
         return true;
      }

      public function connect(param1:String, param2:int) : void
      {
         this.stop();
         this._mode = MODE_CLIENT;
         this._connectedHost = param1;
         this._connectedPort = param2;
         this._localPlayerId = 0;
         this._client = new MultiplayerClient();
         this._client.connectedSignal.add(this.onClientConnected);
         this._client.packetSignal.add(this.onClientPacket);
         this._client.disconnectedSignal.add(this.onClientDisconnected);
         this._client.errorSignal.add(this.onNetworkError);
         this.setStatus("CONNECTING...");
         try
         {
            this._client.connect(param1,param2);
         }
         catch(e:Error)
         {
            this.setStatus("CONNECTION FAILED: " + e.message);
         }
      }

      public function stop() : void
      {
         if(this._stopping)
         {
            return;
         }
         this._stopping = true;
         this._connectedHost = "";
         if(this._server != null)
         {
            try
            {
               this._server.broadcast(MultiplayerProtocol.HOST_DISCONNECTED,HOST_PLAYER_ID);
            }
            catch(e1:Error)
            {
            }
            this._server.stop();
            this._server = null;
         }
         if(this._client != null)
         {
            this._client.disconnect();
            this._client = null;
         }
         this.detachWorldSignals();
         this._mode = MODE_OFF;
         this._operatorPlayers = new Dictionary();
         this._lastCommandTimes = new Dictionary();
         this.typingPlayers = new Dictionary();
         this.xrayAllowedPlayers = new Dictionary();
         this.xrayEnabled = false;
         this._lastLocalTypingTime = 0;
         this.chatInputActive = false;
         this.suppressPauseOnce = false;
         this._localPlayerId = 0;
         this._nextPlayerId = 2;
         this._nextCreatureId = 1000;
         this._connectionIds = new Dictionary(true);
         this._idConnections = new Dictionary();
         this._profiles = new Dictionary();
         this._pvpPlayers = new Dictionary();
         this._remotePlayers = new Dictionary();
         this._creaturesById = new Dictionary();
         this._creatureIds = new Dictionary(true);
         this._lastShootTimes = new Dictionary();
         this._lastConsumeTimes = new Dictionary();
         this._lastAttackTimes = new Dictionary();
         this._destroySessions = new Dictionary();
         this._gameReady = false;
         this._inputTimer = 0;
         this._snapshotTimer = 0;
         this._pingTimer = 0;
         this._dynamicTimer = 0;
         this._inventorySyncTimer = 0;
         this._inventoryLayoutTimer = 0;
         this._inventoryLayoutDirty = false;
         this._chestLayoutTimer = 0;
         this._chestLayoutDirty = false;
         this._dirtyChest = null;
         this._dynamicDirty = false;
         this._stopping = false;
      }

      public function onGameStarted() : void
      {
         if(!this.active || Context.game == null || Context.world == null)
         {
            return;
         }
         this._gameReady = true;
         Context.world.player.networkId = this._localPlayerId;
         if(this.isClient)
         {
            Context.world.gameTimeEnabled = false;
            Context.world.spawnMobsEnabled = false;
            Context.world.mobsDropLootEnabled = false;
            Context.world.removeMobsEnabled = false;
            this.createPendingRemotePlayers();
            if(this._client != null)
            {
               this._client.send(MultiplayerProtocol.WORLD_READY,this._localPlayerId);
            }
         }
         else
         {
            this.attachWorldSignals();
            this.registerExistingHostCreatures();
            this.createPendingHostPlayers();
            this.sendWorldToPendingConnections();
         }
         this.playersChangedSignal.dispatch(this.playerCount);
      }

      public function fixedUpdate(param1:int) : void
      {
         if(!this.active || !this._gameReady || Context.game == null || Context.world == null)
         {
            return;
         }
         if(this.isClient)
         {
            this._inputTimer += param1;
            while(this._inputTimer >= PLAYER_INPUT_INTERVAL)
            {
               this._inputTimer -= PLAYER_INPUT_INTERVAL;
               this.sendLocalInput();
            }
            if(this._chestLayoutDirty)
            {
               this._chestLayoutTimer += param1;
               if(this._chestLayoutTimer >= INVENTORY_LAYOUT_DELAY)
               {
                  this._chestLayoutDirty = false;
                  this._chestLayoutTimer = 0;
                  this._inventoryLayoutDirty = false;
                  this._inventoryLayoutTimer = 0;
                  this.sendTileInventoryLayout(this._dirtyChest);
                  this._dirtyChest = null;
               }
            }
            else if(this._inventoryLayoutDirty)
            {
               this._inventoryLayoutTimer += param1;
               if(this._inventoryLayoutTimer >= INVENTORY_LAYOUT_DELAY)
               {
                  this._inventoryLayoutDirty = false;
                  this._inventoryLayoutTimer = 0;
                  this.sendInventoryLayout();
               }
            }
         }
         else
         {
            this.updateRemoteRespawns(param1);
            this._snapshotTimer += param1;
            while(this._snapshotTimer >= SNAPSHOT_INTERVAL)
            {
               this._snapshotTimer -= SNAPSHOT_INTERVAL;
               this.broadcastSnapshot();
            }
            this._dynamicTimer += param1;
            if(this._dynamicDirty || this._dynamicTimer >= DYNAMIC_SYNC_INTERVAL)
            {
               this._dynamicDirty = false;
               this._dynamicTimer = 0;
               this.broadcastDynamicWorldState();
            }
            this._inventorySyncTimer += param1;
            if(this._inventorySyncTimer >= INVENTORY_SYNC_INTERVAL)
            {
               this._inventorySyncTimer = 0;
               this.broadcastAllInventoryStates();
            }
         }
         this._pingTimer += param1;
         if(this._pingTimer >= PING_INTERVAL)
         {
            this._pingTimer = 0;
            this.sendPing();
         }
      }

      public function requestBeginDestroy(param1:int, param2:int, param3:int) : Boolean
      {
         if(!this.isClient || this._client == null || !this._gameReady)
         {
            return false;
         }
         var _loc4_:ByteArray = new ByteArray();
         _loc4_.writeInt(param1);
         _loc4_.writeInt(param2);
         _loc4_.writeInt(param3);
         this._client.send(MultiplayerProtocol.REQUEST_BEGIN_DESTROY,this._localPlayerId,_loc4_);
         return true;
      }

      public function requestPlaceBlock(param1:int, param2:int, param3:int, param4:int) : Boolean
      {
         if(!this.isClient || this._client == null)
         {
            return false;
         }
         var _loc5_:ByteArray = new ByteArray();
         _loc5_.writeInt(param1);
         _loc5_.writeInt(param2);
         _loc5_.writeInt(param3);
         _loc5_.writeInt(param4);
         this._client.send(MultiplayerProtocol.REQUEST_PLACE_BLOCK,this._localPlayerId,_loc5_);
         return true;
      }

      public function requestRemoveBlock(param1:int, param2:int) : Boolean
      {
         if(!this.isClient || this._client == null)
         {
            return false;
         }
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeInt(param1);
         _loc3_.writeInt(param2);
         this._client.send(MultiplayerProtocol.REQUEST_REMOVE_BLOCK,this._localPlayerId,_loc3_);
         return true;
      }

      public function requestPlaceWall(param1:int, param2:int, param3:int) : Boolean
      {
         if(!this.isClient || this._client == null)
         {
            return false;
         }
         var _loc4_:ByteArray = new ByteArray();
         _loc4_.writeInt(param1);
         _loc4_.writeInt(param2);
         _loc4_.writeInt(param3);
         this._client.send(MultiplayerProtocol.REQUEST_PLACE_WALL,this._localPlayerId,_loc4_);
         return true;
      }

      public function requestRemoveWall(param1:int, param2:int) : Boolean
      {
         if(!this.isClient || this._client == null)
         {
            return false;
         }
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeInt(param1);
         _loc3_.writeInt(param2);
         this._client.send(MultiplayerProtocol.REQUEST_REMOVE_WALL,this._localPlayerId,_loc3_);
         return true;
      }

      public function requestItemPickup(param1:ItemEntity) : Boolean
      {
         if(!this.isClient || this._client == null || param1 == null || param1.itemStack == null)
         {
            return false;
         }
         var _loc2_:ByteArray = new ByteArray();
         _loc2_.writeDouble(param1.position.x);
         _loc2_.writeDouble(param1.position.y);
         _loc2_.writeInt(param1.itemStack.item.id);
         this._client.send(MultiplayerProtocol.REQUEST_ITEM_PICKUP,this._localPlayerId,_loc2_);
         return true;
      }

      public function requestDropItem(param1:ItemStack) : Boolean
      {
         if(!this.isClient || this._client == null || param1 == null || param1.item == null || param1.count <= 0)
         {
            return false;
         }
         var _loc2_:ByteArray = new ByteArray();
         ItemStack.save(_loc2_,param1);
         this._client.send(MultiplayerProtocol.REQUEST_DROP_ITEM,this._localPlayerId,_loc2_);
         return true;
      }

      public function requestAttack(param1:CreatureEntity) : Boolean
      {
         if(!this.isClient || this._client == null || param1 == null || param1.networkId == 0)
         {
            return false;
         }
         var _loc2_:ByteArray = new ByteArray();
         _loc2_.writeInt(param1.networkId);
         this._client.send(MultiplayerProtocol.REQUEST_ATTACK,this._localPlayerId,_loc2_);
         return true;
      }

      public function requestShoot(param1:Number, param2:Number) : Boolean
      {
         if(!this.isClient || this._client == null || !this._gameReady)
         {
            return false;
         }
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeDouble(param1);
         _loc3_.writeDouble(param2);
         this._client.send(MultiplayerProtocol.REQUEST_SHOOT,this._localPlayerId,_loc3_);
         return true;
      }

      public function requestConsume(param1:int, param2:int) : Boolean
      {
         if(!this.isClient || this._client == null || !this._gameReady)
         {
            return false;
         }
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeInt(param1);
         _loc3_.writeInt(param2);
         this._client.send(MultiplayerProtocol.REQUEST_CONSUME,this._localPlayerId,_loc3_);
         return true;
      }

      public function requestTreasureChestOpen(param1:int, param2:int) : Boolean
      {
         if(!this.isClient || this._client == null || !this._gameReady)
         {
            return false;
         }
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeInt(param1);
         _loc3_.writeInt(param2);
         this._client.send(MultiplayerProtocol.REQUEST_TREASURE_OPEN,this._localPlayerId,_loc3_);
         return true;
      }

      public function notifyLocalInventoryLayoutChanged() : void
      {
         if(this.isClient && this._gameReady)
         {
            this._inventoryLayoutDirty = true;
            this._inventoryLayoutTimer = 0;
         }
      }

      public function notifyChestLayoutChanged(param1:BaseChestTileEntity) : void
      {
         this.notifyTileInventoryLayoutChanged(param1);
      }

      public function notifyTileInventoryLayoutChanged(param1:TileEntity) : void
      {
         if(this.isClient && this._gameReady && param1 != null && this.getTileInventoryItems(param1) != null)
         {
            this._dirtyChest = param1;
            this._chestLayoutDirty = true;
            this._chestLayoutTimer = 0;
         }
      }

      public function requestTileAction(param1:TileEntity, param2:int) : Boolean
      {
         if(!this.isClient || this._client == null || !this._gameReady || param1 == null)
         {
            return false;
         }
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeInt(param1.x);
         _loc3_.writeInt(param1.y);
         _loc3_.writeInt(param1.type);
         _loc3_.writeInt(param2);
         this._client.send(MultiplayerProtocol.REQUEST_TILE_ACTION,this._localPlayerId,_loc3_);
         return true;
      }

      public function requestCraft(param1:int, param2:int, param3:int, param4:int, param5:int) : Boolean
      {
         if(!this.isClient || this._client == null)
         {
            return false;
         }
         var _loc6_:ByteArray = new ByteArray();
         _loc6_.writeInt(param1);
         _loc6_.writeInt(param2);
         _loc6_.writeInt(param3);
         _loc6_.writeInt(param4);
         _loc6_.writeInt(param5);
         this._client.send(MultiplayerProtocol.REQUEST_CRAFT,this._localPlayerId,_loc6_);
         return true;
      }

      public function requestRepair(param1:ItemStack, param2:Item) : Boolean
      {
         if(!this.isClient || this._client == null || param1 == null || param1.item == null || param2 == null)
         {
            return false;
         }
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeInt(param1.item.id);
         _loc3_.writeInt(param1.itemData);
         _loc3_.writeInt(param2.id);
         this._client.send(MultiplayerProtocol.REQUEST_REPAIR,this._localPlayerId,_loc3_);
         return true;
      }

      public function hostWorldChanged(param1:int, param2:int) : void
      {
         if(!this.isHost || !this._gameReady)
         {
            return;
         }
         this.broadcastTilePatch(param1,param2,4);
         this._dynamicDirty = true;
      }

      public function markDynamicWorldDirty() : void
      {
         if(this.isHost && this._gameReady)
         {
            this._dynamicDirty = true;
         }
      }

      public function getLocalIPv4() : String
      {
         var _loc1_:Vector.<NetworkInterface> = null;
         var _loc2_:NetworkInterface = null;
         var _loc3_:InterfaceAddress = null;
         var _loc4_:String = null;
         var vpnIp:String = null;
         var lanIp:String = null;
         var otherIp:String = null;
         try
         {
            _loc1_ = NetworkInfo.networkInfo.findInterfaces();
            for each(_loc2_ in _loc1_)
            {
               if(_loc2_.active)
               {
                  for each(_loc3_ in _loc2_.addresses)
                  {
                     _loc4_ = _loc3_.address;
                     if(_loc4_ != null && _loc4_.indexOf(".") >= 0 && _loc4_.indexOf("127.") != 0 && _loc4_.indexOf("169.254.") != 0 && _loc4_ != "0.0.0.0" && _loc4_ != "255.255.255.255")
                     {
                        if(_loc4_.indexOf("26.") == 0 || _loc4_.indexOf("25.") == 0)
                        {
                           vpnIp = _loc4_;
                        }
                        else if(_loc4_.indexOf("192.168.") == 0 || _loc4_.indexOf("10.") == 0 || _loc4_.indexOf("172.") == 0)
                        {
                           if(lanIp == null)
                           {
                              lanIp = _loc4_;
                           }
                        }
                        else if(otherIp == null)
                        {
                           otherIp = _loc4_;
                        }
                     }
                  }
               }
            }
         }
         catch(e:Error)
         {
         }
         if(vpnIp != null)
         {
            return vpnIp;
         }
         if(lanIp != null)
         {
            return lanIp;
         }
         if(otherIp != null)
         {
            return otherIp;
         }
         return "127.0.0.1";
      }

      public function getLanIPv4() : String
      {
         var _loc1_:Vector.<NetworkInterface> = null;
         var _loc2_:NetworkInterface = null;
         var _loc3_:InterfaceAddress = null;
         var _loc4_:String = null;
         try
         {
            _loc1_ = NetworkInfo.networkInfo.findInterfaces();
            for each(_loc2_ in _loc1_)
            {
               if(_loc2_.active)
               {
                  for each(_loc3_ in _loc2_.addresses)
                  {
                     _loc4_ = _loc3_.address;
                     if(_loc4_ != null && _loc4_.indexOf(".") >= 0 && _loc4_.indexOf("127.") != 0 && _loc4_.indexOf("169.254.") != 0 && _loc4_ != "0.0.0.0" && _loc4_ != "255.255.255.255")
                     {
                        if(_loc4_.indexOf("192.168.") == 0 || _loc4_.indexOf("10.") == 0 || _loc4_.indexOf("172.") == 0)
                        {
                           return _loc4_;
                        }
                     }
                  }
               }
            }
         }
         catch(e:Error)
         {
         }
         return this.getLocalIPv4();
      }

      public function getLocalIPv4All() : String
      {
         var _loc1_:Vector.<NetworkInterface>;
         var _loc2_:NetworkInterface;
         var _loc3_:InterfaceAddress;
         var _loc4_:String = null;
         var vpnIp:String = null;
         var lanIp:String = null;
         var otherList:Array = [];
         try
         {
            _loc1_ = NetworkInfo.networkInfo.findInterfaces();
            for each(_loc2_ in _loc1_)
            {
               if(_loc2_.active)
               {
                  for each(_loc3_ in _loc2_.addresses)
                  {
                     _loc4_ = _loc3_.address;
                     if(_loc4_ != null && _loc4_.indexOf(".") >= 0 && _loc4_.indexOf("127.") != 0 && _loc4_.indexOf("169.254.") != 0 && _loc4_ != "0.0.0.0" && _loc4_ != "255.255.255.255")
                     {
                        if(_loc4_.indexOf("26.") == 0 || _loc4_.indexOf("25.") == 0)
                        {
                           vpnIp = _loc4_;
                        }
                        else if(_loc4_.indexOf("192.168.") == 0 || _loc4_.indexOf("10.") == 0 || _loc4_.indexOf("172.") == 0)
                        {
                           if(lanIp == null)
                           {
                              lanIp = _loc4_;
                           }
                        }
                        else
                        {
                           otherList.push(_loc4_);
                        }
                     }
                  }
               }
            }
         }
         catch(e:Error)
         {
         }
         if(vpnIp != null && lanIp != null)
         {
            return vpnIp + " (VPN)   |   " + lanIp + " (LAN)";
         }
         if(vpnIp != null)
         {
            return vpnIp + " (VPN)";
         }
         if(lanIp != null)
         {
            return lanIp;
         }
         if(otherList.length > 0)
         {
            return String(otherList[0]);
         }
         return this.getLocalIPv4();
      }

      private function onServerConnection(param1:NetworkConnection) : void
      {
         this.setStatus("CLIENT CONNECTED - HANDSHAKE");
      }

      private function onServerPacket(param1:NetworkConnection, param2:NetworkPacket) : void
      {
         if(param2.protocolVersion != MultiplayerProtocol.PROTOCOL_VERSION)
         {
            this.rejectConnection(param1,"PROTOCOL VERSION MISMATCH");
            return;
         }
         switch(param2.type)
         {
            case MultiplayerProtocol.COMMAND_REQUEST:
               this.handleCommandRequest(param1,param2.payload);
               break;
            case MultiplayerProtocol.TYPING_STATE:
               if(this._connectionIds[param1] == null || param2.payload.bytesAvailable < 5)
               {
                  break;
               }
               param2.payload.readInt();
               var stpId:int = int(this._connectionIds[param1]);
               var stpBool:Boolean = param2.payload.readBoolean();
               this.typingPlayers[stpId] = stpBool ? getTimer() + 3000 : 0;
               var stout:ByteArray = new ByteArray();
               stout.writeInt(stpId);
               stout.writeBoolean(stpBool);
               this._server.broadcast(MultiplayerProtocol.TYPING_STATE,stpId,stout,param1);
               break;
            case MultiplayerProtocol.CHAT:
               var smsg:String = param2.payload.readUTF();
               this.chatSignal.dispatch(smsg);
               var out:ByteArray = new ByteArray();
               out.writeUTF(smsg);
               this._server.broadcast(MultiplayerProtocol.CHAT,0,out,param1);
               break;
            case MultiplayerProtocol.HELLO:
               this.handleHello(param1,param2);
               break;
            case MultiplayerProtocol.WORLD_READY:
               this.handleWorldReady(param1);
               break;
            case MultiplayerProtocol.PLAYER_INPUT:
               this.handlePlayerInput(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_BEGIN_DESTROY:
               this.handleBeginDestroy(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_PLACE_BLOCK:
               this.handlePlaceBlock(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_REMOVE_BLOCK:
               this.handleRemoveBlock(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_PLACE_WALL:
               this.handlePlaceWall(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_REMOVE_WALL:
               this.handleRemoveWall(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_ITEM_PICKUP:
               this.handleItemPickup(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_DROP_ITEM:
               this.handleDropItem(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_ATTACK:
               this.handleAttack(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_PVP_STATE:
               this.handlePvpStateRequest(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_INVENTORY_LAYOUT:
               this.handleInventoryLayout(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_CRAFT:
               this.handleCraft(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_REPAIR:
               this.handleRepair(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_SHOOT:
               this.handleShoot(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_CONSUME:
               this.handleConsume(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_CHEST_LAYOUT:
               this.handleChestLayout(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_TREASURE_OPEN:
               this.handleTreasureChestOpen(param1,param2.payload);
               break;
            case MultiplayerProtocol.REQUEST_TILE_ACTION:
               this.handleTileAction(param1,param2.payload);
               break;
            case MultiplayerProtocol.PING:
               param1.send(MultiplayerProtocol.PONG,HOST_PLAYER_ID,param2.payload);
         }
      }

      private function handleHello(param1:NetworkConnection, param2:NetworkPacket) : void
      {
         var _loc5_:ByteArray;
         var clientIp:String;
         var clientNick:String;
         var _loc1_:String = null;
         var _loc2_:String = null;
         var _loc3_:Object = null;
         var _loc4_:int = 0;
         try
         {
            _loc1_ = param2.payload.readUTF();
            _loc2_ = param2.payload.readUTF();
            _loc3_ = param2.payload.readObject();
         }
         catch(e:Error)
         {
            this.rejectConnection(param1,"MALFORMED HELLO");
            return;
         }
         if(_loc1_ != GameInfo.VERSION)
         {
            this.rejectConnection(param1,"GAME VERSION MISMATCH");
            return;
         }
         if(_loc2_ != MultiplayerProtocol.MOD_VERSION)
         {
            this.rejectConnection(param1,"MULTIPLAYER VERSION MISMATCH");
            return;
         }
         if(this._gameReady)
         {
            this.rejectConnection(param1,"GAME ALREADY STARTED");
            return;
         }
         clientIp = param1.remoteAddress;
         clientNick = _loc3_ != null && _loc3_.name != null ? String(_loc3_.name) : "";
         if(this.isBanned(clientNick,clientIp))
         {
            this.rejectConnection(param1,"BANNED BY HOST");
            this.systemMessage(this.getBannedRejectedText() + clientNick + (clientIp.length > 0 ? " [" + clientIp + "]" : ""));
            return;
         }
         _loc4_ = this._nextPlayerId++;
         this._connectionIds[param1] = _loc4_;
         this._idConnections[_loc4_] = param1;
         this._profiles[_loc4_] = _loc3_;
         this._pvpPlayers[_loc4_] = false;
         _loc5_ = new ByteArray();
         _loc5_.writeInt(_loc4_);
         _loc5_.writeInt(HOST_PLAYER_ID);
         param1.send(MultiplayerProtocol.WELCOME,HOST_PLAYER_ID,_loc5_);
         this.sendAllPvpStates(param1);
         this.sendAllOperatorStates(param1);
         this.sendAllPlayerDescriptors(param1);
         this.broadcastPlayerJoin(_loc4_,_loc3_,param1);
         if(this._gameReady)
         {
            this.createHostRemotePlayer(_loc4_);
            this.sendInitialState(param1);
         }
         this.playersChangedSignal.dispatch(this.playerCount);
         this.setStatus("PLAYER " + _loc4_ + " CONNECTED");
      }

      private function rejectConnection(param1:NetworkConnection, param2:String) : void
      {
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeUTF(param2);
         param1.send(MultiplayerProtocol.REJECT,HOST_PLAYER_ID,_loc3_);
         param1.close();
      }

      private function handleWorldReady(param1:NetworkConnection) : void
      {
         var _loc2_:Object = this._connectionIds[param1];
         if(_loc2_ == null)
         {
            return;
         }
         this.broadcastAllInventoryStates();
      }

      private function onServerDisconnect(param1:NetworkConnection) : void
      {
         var _loc2_:Object = this._connectionIds[param1];
         if(_loc2_ == null)
         {
            return;
         }
         var _loc3_:int = int(_loc2_);
         delete this._connectionIds[param1];
         delete this._idConnections[_loc3_];
         delete this._profiles[_loc3_];
         delete this._pvpPlayers[_loc3_];
         delete this._operatorPlayers[_loc3_];
         delete this._lastCommandTimes[_loc3_];
         delete this.typingPlayers[_loc3_];
         delete this.xrayAllowedPlayers[_loc3_];
         this.sendOperatorState(_loc3_,false);
         var _loc4_:RemotePlayerEntity = this._remotePlayers[_loc3_] as RemotePlayerEntity;
         if(_loc4_ != null && Context.world != null)
         {
            delete this._remotePlayers[_loc3_];
            Context.world.removeCreature(_loc4_);
         }
         if(this._server != null)
         {
            var _loc5_:ByteArray = new ByteArray();
            _loc5_.writeInt(_loc3_);
            this._server.broadcast(MultiplayerProtocol.PLAYER_LEAVE,HOST_PLAYER_ID,_loc5_);
         }
         this.playersChangedSignal.dispatch(this.playerCount);
         this.setStatus("PLAYER " + _loc3_ + " LEFT");
      }

      private function onClientConnected() : void
      {
         var _loc1_:ByteArray = new ByteArray();
         _loc1_.writeUTF(GameInfo.VERSION);
         _loc1_.writeUTF(MultiplayerProtocol.MOD_VERSION);
         _loc1_.writeObject(this.getLocalProfile());
         this._client.send(MultiplayerProtocol.HELLO,0,_loc1_);
         this.setStatus("CONNECTED - HANDSHAKE");
      }

      private function onClientPacket(param1:NetworkPacket) : void
      {
         var _loc2_:String = null;
         switch(param1.type)
         {
            case MultiplayerProtocol.COMMAND_RESULT:
               this.chatSignal.dispatch(param1.payload.readUTF());
               break;
            case MultiplayerProtocol.OP_STATE:
               if(param1.payload.bytesAvailable < 5)
               {
                  break;
               }
               var operatorId:int = param1.payload.readInt();
               var operatorEnabled:Boolean = param1.payload.readBoolean();
               this._operatorPlayers[operatorId] = operatorEnabled;
               this.playersChangedSignal.dispatch(this.playerCount);
               if(operatorId == this._localPlayerId)
               {
                  this.systemMessage(this.isRussian ? (operatorEnabled ? "Вам выданы права оператора. /help" : "Права оператора сняты.") : (operatorEnabled ? "You are now an operator. /help" : "Operator permission removed."));
               }
               break;
            case MultiplayerProtocol.ADMIN_TELEPORT:
               if(param1.payload.bytesAvailable < 16 || Context.world == null || Context.world.player == null)
               {
                  break;
               }
               var teleportX:Number = param1.payload.readDouble();
               var teleportY:Number = param1.payload.readDouble();
               Context.world.player.setPosition(teleportX,teleportY);
               Context.world.player.velocity.x = 0;
               Context.world.player.velocity.y = 0;
               Context.world.player.notDamageFromFirstFall();
               break;
            case MultiplayerProtocol.RETURN_TO_LOBBY:
               this.setStatus("RETURN_TO_LOBBY");
               this.onReturnToLobby();
               if(Context.app != null)
               {
                  Context.app.returnToMultiplayerLobby();
               }
               break;
            case MultiplayerProtocol.TYPING_STATE:
               var ctpId:int = param1.payload.readInt();
               var ctpBool:Boolean = param1.payload.readBoolean();
               this.typingPlayers[ctpId] = ctpBool ? getTimer() + 3000 : 0;
               break;
            case MultiplayerProtocol.XRAY_STATE:
               var rxId:int = param1.payload.readInt();
               var rxOn:Boolean = param1.payload.readBoolean();
               this.xrayAllowedPlayers[rxId] = rxOn;
               if(rxId == this._localPlayerId)
               {
                  this.xrayEnabled = rxOn;
                  this.systemMessage(this.isRussian ? (rxOn ? "Вам выдан X-Ray!" : "Хост отключил вам X-Ray.") : (rxOn ? "X-Ray enabled for you!" : "X-Ray disabled for you."));
               }
               break;
            case MultiplayerProtocol.CHAT:
               var cmsg:String = param1.payload.readUTF();
               this.chatSignal.dispatch(cmsg);
               break;
            case MultiplayerProtocol.PVP_STATE:
               var _locPvpPlayerId_:int = param1.payload.readInt();
               this._pvpPlayers[_locPvpPlayerId_] = param1.payload.readBoolean();
               break;
            case MultiplayerProtocol.ADMIN_XP:
               if(Context.world != null && Context.world.player != null)
               {
                  Context.world.player.addExperience(param1.payload.readInt());
                  Context.app.saveCurrentProfile();
               }
               break;
            case MultiplayerProtocol.ADMIN_LEVEL:
               if(Context.world != null && Context.world.player != null)
               {
                  Context.world.player.experience = param1.payload.readInt();
                  Context.app.saveCurrentProfile();
               }
               break;
            case MultiplayerProtocol.PVP_DEATH:
               if(Context.world != null && Context.world.player != null)
               {
                  Context.world.player["suppressNextDeathExperienceLoss"] = true;
               }
               break;
            case MultiplayerProtocol.WELCOME:
               this._localPlayerId = param1.payload.readInt();
               param1.payload.readInt();
               this._profiles[this._localPlayerId] = this.getLocalProfile();
               if(this._pvpPlayers[this._localPlayerId] == null)
               {
                  this._pvpPlayers[this._localPlayerId] = false;
               }
               this.setStatus("CONNECTED AS PLAYER " + this._localPlayerId);
               this.playersChangedSignal.dispatch(this.playerCount);
               break;
            case MultiplayerProtocol.REJECT:
               _loc2_ = param1.payload.readUTF();
               this.setStatus(_loc2_);
               if(this._client != null)
               {
                  this._client.disconnect();
               }
               break;
            case MultiplayerProtocol.WORLD_INIT:
               this.handleWorldInit(param1.payload);
               break;
            case MultiplayerProtocol.PLAYER_JOIN:
               this.handlePlayerJoin(param1.payload);
               break;
            case MultiplayerProtocol.PLAYER_LEAVE:
               this.handlePlayerLeave(param1.payload);
               break;
            case MultiplayerProtocol.SNAPSHOT:
               this.handleSnapshot(param1.payload);
               break;
            case MultiplayerProtocol.CREATURE_SPAWN:
               this.handleCreatureSpawn(param1.payload);
               break;
            case MultiplayerProtocol.CREATURE_REMOVE:
               this.handleCreatureRemove(param1.payload);
               break;
            case MultiplayerProtocol.TILE_PATCH:
               if(Context.world != null)
               {
                  Context.world.applyNetworkTilePatch(param1.payload);
               }
               break;
            case MultiplayerProtocol.DYNAMIC_WORLD_STATE:
               if(Context.world != null)
               {
                  Context.world.loadNetworkDynamicState(param1.payload);
               }
               break;
            case MultiplayerProtocol.INVENTORY_SYNC:
               this.handleInventorySync(param1.payload);
               break;
            case MultiplayerProtocol.PROJECTILE_SPAWN:
               this.handleProjectileSpawn(param1.payload);
               break;
            case MultiplayerProtocol.TREASURE_OPEN_RESULT:
               this.handleTreasureOpenResult(param1.payload);
               break;
            case MultiplayerProtocol.PING:
               if(this._client != null)
               {
                  this._client.send(MultiplayerProtocol.PONG,this._localPlayerId,param1.payload);
               }
               break;
            case MultiplayerProtocol.HOST_DISCONNECTED:
               this.setStatus("HOST DISCONNECTED");
               if(Context.game != null)
               {
                  Context.app.quitGame();
               }
               break;
            case MultiplayerProtocol.ERROR:
               this.setStatus(param1.payload.readUTF());
         }
      }

      private function handleWorldInit(param1:ByteArray) : void
      {
         var _loc2_:ByteArray = new ByteArray();
         param1.position = 0;
         param1.readBytes(_loc2_,0,param1.length);
         _loc2_.position = 0;
         this.setStatus("WORLD RECEIVED");
         Context.app.startMultiplayerClientGame(_loc2_);
      }

      private function handlePlayerJoin(param1:ByteArray) : void
      {
         var _loc2_:int = param1.readInt();
         var _loc3_:Object = param1.readObject();
         this._profiles[_loc2_] = _loc3_;
         if(this._pvpPlayers[_loc2_] == null)
         {
            this._pvpPlayers[_loc2_] = false;
         }
         if(this._gameReady && _loc2_ != this._localPlayerId)
         {
            this.createClientRemotePlayer(_loc2_);
         }
         this.playersChangedSignal.dispatch(this.playerCount);
      }

      private function handlePlayerLeave(param1:ByteArray) : void
      {
         var _loc2_:int = param1.readInt();
         delete this._profiles[_loc2_];
         delete this._pvpPlayers[_loc2_];
         var _loc3_:RemotePlayerEntity = this._remotePlayers[_loc2_] as RemotePlayerEntity;
         if(_loc3_ != null && Context.world != null)
         {
            delete this._remotePlayers[_loc2_];
            Context.world.removeCreature(_loc3_);
         }
         this.playersChangedSignal.dispatch(this.playerCount);
      }

      private function sendInitialState(param1:NetworkConnection) : void
      {
         this.sendAllPlayerDescriptors(param1);
         this.sendWorldSnapshot(param1);
         this.sendAllCreatureSpawns(param1);
      }

      private function sendWorldSnapshot(param1:NetworkConnection) : void
      {
         if(Context.game == null || Context.world == null || !Context.world.created)
         {
            return;
         }
         var _loc2_:ByteArray = new ByteArray();
         Context.game.saveWorld(_loc2_);
         _loc2_.position = 0;
         param1.send(MultiplayerProtocol.WORLD_INIT,HOST_PLAYER_ID,_loc2_);
      }

      private function sendAllPlayerDescriptors(param1:NetworkConnection) : void
      {
         this.sendPlayerDescriptor(param1,HOST_PLAYER_ID,this.getHostProfile());
         var _loc2_:Object = null;
         var _loc3_:int = 0;
         for(_loc2_ in this._profiles)
         {
            _loc3_ = int(_loc2_);
            if(_loc3_ != HOST_PLAYER_ID)
            {
               this.sendPlayerDescriptor(param1,_loc3_,this._profiles[_loc3_]);
            }
         }
      }

      private function sendPlayerDescriptor(param1:NetworkConnection, param2:int, param3:Object) : void
      {
         var _loc4_:ByteArray = new ByteArray();
         _loc4_.writeInt(param2);
         _loc4_.writeObject(param3);
         param1.send(MultiplayerProtocol.PLAYER_JOIN,HOST_PLAYER_ID,_loc4_);
      }

      private function broadcastPlayerJoin(param1:int, param2:Object, param3:NetworkConnection = null) : void
      {
         if(this._server == null)
         {
            return;
         }
         var _loc4_:ByteArray = new ByteArray();
         _loc4_.writeInt(param1);
         _loc4_.writeObject(param2);
         this._server.broadcast(MultiplayerProtocol.PLAYER_JOIN,HOST_PLAYER_ID,_loc4_,param3);
      }

      private function createPendingHostPlayers() : void
      {
         var _loc1_:Object = null;
         var _loc2_:int = 0;
         for(_loc1_ in this._profiles)
         {
            _loc2_ = int(_loc1_);
            if(_loc2_ != HOST_PLAYER_ID && this._remotePlayers[_loc2_] == null)
            {
               this.createHostRemotePlayer(_loc2_);
            }
         }
      }

      private function createHostRemotePlayer(param1:int) : RemotePlayerEntity
      {
         if(Context.world == null)
         {
            return null;
         }
         var _loc2_:RemotePlayerEntity = this._remotePlayers[param1] as RemotePlayerEntity;
         if(_loc2_ != null)
         {
            return _loc2_;
         }
         _loc2_ = new RemotePlayerEntity(param1,false);
         _loc2_.applyProfile(this._profiles[param1]);
         this.placeAtGuestSpawn(_loc2_);
         Context.world.addCreature(_loc2_);
         this._remotePlayers[param1] = _loc2_;
         return _loc2_;
      }

      private function createPendingRemotePlayers() : void
      {
         var _loc1_:Object = null;
         var _loc2_:int = 0;
         for(_loc1_ in this._profiles)
         {
            _loc2_ = int(_loc1_);
            if(_loc2_ != this._localPlayerId)
            {
               this.createClientRemotePlayer(_loc2_);
            }
         }
      }

      private function createClientRemotePlayer(param1:int) : RemotePlayerEntity
      {
         if(Context.world == null || param1 == this._localPlayerId)
         {
            return null;
         }
         var _loc2_:RemotePlayerEntity = this._remotePlayers[param1] as RemotePlayerEntity;
         if(_loc2_ != null)
         {
            return _loc2_;
         }
         _loc2_ = new RemotePlayerEntity(param1,true);
         _loc2_.applyProfile(this._profiles[param1]);
         this.placeAtGuestSpawn(_loc2_);
         Context.world.addCreature(_loc2_);
         this._remotePlayers[param1] = _loc2_;
         return _loc2_;
      }

      private function placeAtGuestSpawn(param1:CreatureEntity) : void
      {
         var _loc2_:int = 0;
         var _loc3_:int = 0;
         if(Context.world.hasSpawnPortal())
         {
            _loc2_ = Context.world.spawnPortalX * Tile.SIZE;
            _loc3_ = Context.world.spawnPortalY * Tile.SIZE + Tile.SIZE * 2 - param1.height;
         }
         else
         {
            _loc2_ = Context.world.spawnPlayerX * Tile.SIZE;
            _loc3_ = Context.world.spawnPlayerY * Tile.SIZE + Tile.SIZE * 2 - param1.height;
         }
         param1.setPosition(_loc2_,_loc3_);
      }

      private function handlePlayerInput(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:Object = this._connectionIds[param1];
         if(_loc3_ == null)
         {
            return;
         }
         var _loc4_:RemotePlayerEntity = this._remotePlayers[int(_loc3_)] as RemotePlayerEntity;
         if(_loc4_ == null)
         {
            return;
         }
         var _loc5_:int = param2.readInt();
         var _loc6_:Number = param2.readDouble();
         var _loc7_:Number = param2.readDouble();
         var _loc8_:int = param2.readInt();
         _loc4_.setInputState(_loc5_,_loc6_,_loc7_,_loc8_);
      }

      private function sendLocalInput() : void
      {
         if(this._client == null || Context.world == null || Context.game == null)
         {
            return;
         }
         var _loc1_:int = 0;
         if(!this.chatInputActive)
         {
            if(Context.input.keyDown(Key.W) || Context.input.keyDown(Key.UP))
            {
               _loc1_ |= MultiplayerProtocol.INPUT_UP;
            }
            if(Context.input.keyDown(Key.S) || Context.input.keyDown(Key.DOWN))
            {
               _loc1_ |= MultiplayerProtocol.INPUT_DOWN;
            }
            if(Context.input.keyDown(Key.A) || Context.input.keyDown(Key.LEFT))
            {
               _loc1_ |= MultiplayerProtocol.INPUT_LEFT;
            }
            if(Context.input.keyDown(Key.D) || Context.input.keyDown(Key.RIGHT))
            {
               _loc1_ |= MultiplayerProtocol.INPUT_RIGHT;
            }
            if(Context.input.keyDown(Keyboard.SPACE) || Context.input.keyDown(Key.W) || Context.input.keyDown(Key.UP) || Context.input.keyDown(Keyboard.ENTER))
            {
               _loc1_ |= MultiplayerProtocol.INPUT_JUMP;
            }
         }
         var _loc2_:ByteArray = new ByteArray();
         _loc2_.writeInt(_loc1_);
         _loc2_.writeDouble(Context.world.player.headDegrees);
         _loc2_.writeDouble(Context.world.player.armDegrees);
         _loc2_.writeInt(Context.game.controller.selectedItemIndex);
         this._client.send(MultiplayerProtocol.PLAYER_INPUT,this._localPlayerId,_loc2_);
      }

      private function broadcastSnapshot() : void
      {
         if(this._server == null || Context.world == null || Context.game == null)
         {
            return;
         }
         var _loc1_:ByteArray = new ByteArray();
         _loc1_.writeInt(Context.world.gameTime);
         _loc1_.writeInt(Context.world.day);
         _loc1_.writeInt(Context.world.month);
         _loc1_.writeInt(Context.world.year);
         var _loc2_:int = 1;
         var _loc3_:Object = null;
         for(_loc3_ in this._remotePlayers)
         {
            _loc2_++;
         }
         _loc1_.writeInt(_loc2_);
         this.writePlayerState(_loc1_,HOST_PLAYER_ID,Context.world.player,Context.game.controller.selectedItemIndex);
         var _loc4_:RemotePlayerEntity = null;
         for each(_loc4_ in this._remotePlayers)
         {
            this.writePlayerState(_loc1_,_loc4_.networkPlayerId,_loc4_,_loc4_.inventory.itemInHandIndex);
         }
         var _loc5_:int = 0;
         var _loc6_:CreatureEntity = null;
         for each(_loc6_ in this._creaturesById)
         {
            if(_loc6_ != null && _loc6_.active)
            {
               _loc5_++;
            }
         }
         _loc1_.writeInt(_loc5_);
         for each(_loc6_ in this._creaturesById)
         {
            if(_loc6_ != null && _loc6_.active)
            {
               _loc1_.writeInt(_loc6_.networkId);
               _loc1_.writeDouble(_loc6_.position.x);
               _loc1_.writeDouble(_loc6_.position.y);
               _loc1_.writeDouble(_loc6_.velocity.x);
               _loc1_.writeDouble(_loc6_.velocity.y);
               _loc1_.writeInt(_loc6_.direction);
               _loc1_.writeInt(_loc6_.health);
               _loc1_.writeBoolean(_loc6_.alive);
            }
         }
         this._server.broadcast(MultiplayerProtocol.SNAPSHOT,HOST_PLAYER_ID,_loc1_);
      }

      private function writePlayerState(param1:ByteArray, param2:int, param3:CharacterEntity, param4:int) : void
      {
         param1.writeInt(param2);
         param1.writeDouble(param3.position.x);
         param1.writeDouble(param3.position.y);
         param1.writeDouble(param3.velocity.x);
         param1.writeDouble(param3.velocity.y);
         param1.writeInt(param3.direction);
         param1.writeInt(param3.bodyFrame);
         param1.writeInt(param3.handFrame);
         param1.writeDouble(param3.headDegrees);
         param1.writeDouble(param3.armDegrees);
         param1.writeInt(param3.health);
         param1.writeBoolean(param3.alive);
         param1.writeInt(param4);
         param1.writeBoolean(param3.gender);
         param1.writeInt(param3.hairIndex);
         param1.writeInt(param3.headIndex);
         param1.writeInt(param3.hairColorIndex);
         param1.writeInt(param3.buffsEffects.length);
         var _loc5_:BuffEffect = null;
         for each(_loc5_ in param3.buffsEffects)
         {
            param1.writeInt(_loc5_.buff.id);
            param1.writeInt(_loc5_.time);
         }
      }

      private function handleSnapshot(param1:ByteArray) : void
      {
         if(Context.world == null)
         {
            return;
         }
         Context.world.gameTime = param1.readInt();
         Context.world.day = param1.readInt();
         Context.world.month = param1.readInt();
         Context.world.year = param1.readInt();
         var _loc2_:int = param1.readInt();
         var _loc3_:int = 0;
         var _loc4_:int = 0;
         var _loc5_:Number = Number(NaN);
         var _loc6_:Number = Number(NaN);
         var _loc7_:Number = Number(NaN);
         var _loc8_:Number = Number(NaN);
         var _loc9_:int = 0;
         var _loc10_:int = 0;
         var _loc11_:int = 0;
         var _loc12_:Number = Number(NaN);
         var _loc13_:Number = Number(NaN);
         var _loc14_:int = 0;
         var _loc15_:Boolean = false;
         var _loc16_:int = 0;
         var _loc17_:RemotePlayerEntity = null;
         while(_loc3_ < _loc2_)
         {
            _loc4_ = param1.readInt();
            _loc5_ = param1.readDouble();
            _loc6_ = param1.readDouble();
            _loc7_ = param1.readDouble();
            _loc8_ = param1.readDouble();
            _loc9_ = param1.readInt();
            _loc10_ = param1.readInt();
            _loc11_ = param1.readInt();
            _loc12_ = param1.readDouble();
            _loc13_ = param1.readDouble();
            _loc14_ = param1.readInt();
            _loc15_ = param1.readBoolean();
            _loc16_ = param1.readInt();
            var _locPlayerTarget_:CharacterEntity = null;
            if(_loc4_ == this._localPlayerId)
            {
               this.reconcileLocalPlayer(_loc5_,_loc6_,_loc7_,_loc8_,_loc9_,_loc14_,_loc15_);
               _locPlayerTarget_ = Context.world.player;
            }
            else
            {
               _loc17_ = this._remotePlayers[_loc4_] as RemotePlayerEntity;
               if(_loc17_ == null)
               {
                  _loc17_ = this.createClientRemotePlayer(_loc4_);
               }
               if(_loc17_ != null)
               {
                  _loc17_.setReplicaState(_loc5_,_loc6_,_loc7_,_loc8_,_loc9_,_loc10_,_loc11_,_loc12_,_loc13_,_loc14_,_loc15_,_loc16_);
                  _locPlayerTarget_ = _loc17_;
               }
            }
            this.readPlayerVisualState(param1,_locPlayerTarget_);
            _loc3_++;
         }
         var _loc18_:int = param1.readInt();
         _loc3_ = 0;
         while(_loc3_ < _loc18_)
         {
            _loc4_ = param1.readInt();
            _loc5_ = param1.readDouble();
            _loc6_ = param1.readDouble();
            _loc7_ = param1.readDouble();
            _loc8_ = param1.readDouble();
            _loc9_ = param1.readInt();
            _loc14_ = param1.readInt();
            _loc15_ = param1.readBoolean();
            var _loc19_:CreatureEntity = this._creaturesById[_loc4_] as CreatureEntity;
            if(_loc19_ != null)
            {
               _loc19_.setPosition(_loc5_,_loc6_);
               _loc19_.velocity.x = _loc7_;
               _loc19_.velocity.y = _loc8_;
               _loc19_.direction = _loc9_;
               _loc19_.health = _loc14_;
               _loc19_.alive = _loc15_;
            }
            _loc3_++;
         }
      }

      private function readPlayerVisualState(param1:ByteArray, param2:CharacterEntity) : void
      {
         var _loc3_:Boolean = param1.readBoolean();
         var _loc4_:int = param1.readInt();
         var _loc5_:int = param1.readInt();
         var _loc6_:int = param1.readInt();
         var _loc7_:Boolean = false;
         if(param2 != null)
         {
            _loc7_ = param2.gender != _loc3_ || param2.hairIndex != _loc4_ || param2.headIndex != _loc5_ || param2.hairColorIndex != _loc6_;
            param2.gender = _loc3_;
            param2.hairIndex = _loc4_;
            param2.headIndex = _loc5_;
            param2.hairColorIndex = _loc6_;
            if(_loc7_)
            {
               param2.initHairAndHeadTextures();
            }
         }
         var _loc8_:int = param1.readInt();
         var _loc9_:Object = {};
         var _loc10_:int = 0;
         while(_loc10_ < _loc8_)
         {
            var _loc11_:int = param1.readInt();
            var _loc12_:int = param1.readInt();
            _loc9_[_loc11_] = _loc12_;
            if(param2 != null && _loc11_ >= 0 && _loc11_ < Buff.BUFFS.length && Buff.BUFFS[_loc11_] != null)
            {
               var _loc13_:BuffEffect = null;
               var _loc14_:BuffEffect = null;
               for each(_loc14_ in param2.buffsEffects)
               {
                  if(_loc14_.buff.id == _loc11_)
                  {
                     _loc13_ = _loc14_;
                     break;
                  }
               }
               if(_loc13_ == null)
               {
                  param2.addBuff(Buff.BUFFS[_loc11_],_loc12_);
               }
               else
               {
                  _loc13_.time = _loc12_;
               }
            }
            _loc10_++;
         }
         if(param2 != null)
         {
            _loc10_ = int(param2.buffsEffects.length - 1);
            while(_loc10_ >= 0)
            {
               _loc14_ = param2.buffsEffects[_loc10_];
               if(_loc9_[_loc14_.buff.id] === undefined)
               {
                  _loc14_.destroy();
                  param2.buffsEffects.splice(_loc10_,1);
               }
               _loc10_--;
            }
         }
      }

      private function reconcileLocalPlayer(param1:Number, param2:Number, param3:Number, param4:Number, param5:int, param6:int, param7:Boolean) : void
      {
         var _loc8_:PlayerEntity = Context.world.player;
         var _loc9_:Number = _loc8_.position.x - param1;
         var _loc10_:Number = _loc8_.position.y - param2;
         var _loc11_:Number = _loc9_ * _loc9_ + _loc10_ * _loc10_;
         if(_loc11_ > Tile.SIZE * Tile.SIZE * 4)
         {
            _loc8_.setPosition(param1,param2);
         }
         else
         {
            _loc8_.position.x += (param1 - _loc8_.position.x) * 0.15;
            _loc8_.position.y += (param2 - _loc8_.position.y) * 0.15;
            _loc8_.renderPosition.x = Math.round(_loc8_.position.x);
            _loc8_.renderPosition.y = Math.round(_loc8_.position.y);
            _loc8_.center.x = _loc8_.position.x + _loc8_.width * 0.5;
            _loc8_.center.y = _loc8_.position.y + _loc8_.height * 0.5;
         }
         _loc8_.velocity.x = param3;
         _loc8_.velocity.y = param4;
         _loc8_.direction = param5;
         _loc8_.health = param6;
         _loc8_.alive = param7;
      }

      private function registerExistingHostCreatures() : void
      {
         var _loc1_:CreatureEntity = null;
         for each(_loc1_ in Context.world.creatures)
         {
            if(_loc1_ != Context.world.player && !(_loc1_ is RemotePlayerEntity))
            {
               this.registerHostCreature(_loc1_,false);
            }
         }
      }

      private function attachWorldSignals() : void
      {
         if(Context.world == null)
         {
            return;
         }
         Context.world.creatureAddedSignal.add(this.onCreatureAdded);
         Context.world.creatureRemovedSignal.add(this.onCreatureRemoved);
      }

      private function detachWorldSignals() : void
      {
         if(Context.world == null)
         {
            return;
         }
         try
         {
            Context.world.creatureAddedSignal.remove(this.onCreatureAdded);
            Context.world.creatureRemovedSignal.remove(this.onCreatureRemoved);
         }
         catch(e:Error)
         {
         }
      }

      private function onCreatureAdded(param1:CreatureEntity) : void
      {
         if(!this.isHost || param1 == Context.world.player || param1 is RemotePlayerEntity)
         {
            return;
         }
         this.registerHostCreature(param1,true);
      }

      private function onCreatureRemoved(param1:CreatureEntity) : void
      {
         if(!this.isHost || param1 == null || param1 is RemotePlayerEntity)
         {
            return;
         }
         var _loc2_:Object = this._creatureIds[param1];
         if(_loc2_ == null)
         {
            return;
         }
         var _loc3_:int = int(_loc2_);
         delete this._creatureIds[param1];
         delete this._creaturesById[_loc3_];
         if(this._server != null)
         {
            var _loc4_:ByteArray = new ByteArray();
            _loc4_.writeInt(_loc3_);
            this._server.broadcast(MultiplayerProtocol.CREATURE_REMOVE,HOST_PLAYER_ID,_loc4_);
         }
         this._dynamicDirty = true;
      }

      private function registerHostCreature(param1:CreatureEntity, param2:Boolean) : void
      {
         if(!(param1 is MobEntity))
         {
            return;
         }
         if(param1.networkId == 0)
         {
            param1.networkId = this._nextCreatureId++;
         }
         this._creaturesById[param1.networkId] = param1;
         this._creatureIds[param1] = param1.networkId;
         if(param2 && this._server != null)
         {
            this._server.broadcast(MultiplayerProtocol.CREATURE_SPAWN,HOST_PLAYER_ID,this.createCreatureSpawnPayload(param1));
         }
      }

      private function sendAllCreatureSpawns(param1:NetworkConnection) : void
      {
         var _loc2_:CreatureEntity = null;
         for each(_loc2_ in this._creaturesById)
         {
            if(_loc2_ != null && _loc2_.active)
            {
               param1.send(MultiplayerProtocol.CREATURE_SPAWN,HOST_PLAYER_ID,this.createCreatureSpawnPayload(_loc2_));
            }
         }
      }

      private function createCreatureSpawnPayload(param1:CreatureEntity) : ByteArray
      {
         var _loc2_:ByteArray = new ByteArray();
         _loc2_.writeInt(param1.networkId);
         _loc2_.writeUTF(getQualifiedClassName(param1));
         _loc2_.writeDouble(param1.position.x);
         _loc2_.writeDouble(param1.position.y);
         _loc2_.writeInt(param1.level);
         _loc2_.writeInt(param1.health);
         _loc2_.writeInt(param1.direction);
         return _loc2_;
      }

      private function handleCreatureSpawn(param1:ByteArray) : void
      {
         var _loc1_:int;
         var _loc2_:String;
         var _loc3_:Number;
         var _loc4_:Number;
         var _loc5_:int;
         var _loc6_:int;
         var _loc7_:int;
         var _loc8_:Class;
         var _loc9_:CreatureEntity;
         if(Context.world == null)
         {
            return;
         }
         _loc1_ = param1.readInt();
         _loc2_ = param1.readUTF();
         _loc3_ = param1.readDouble();
         _loc4_ = param1.readDouble();
         _loc5_ = param1.readInt();
         _loc6_ = param1.readInt();
         _loc7_ = param1.readInt();
         if(this._creaturesById[_loc1_] != null)
         {
            return;
         }
         try
         {
            _loc8_ = getDefinitionByName(_loc2_) as Class;
            _loc9_ = new _loc8_(_loc3_,_loc4_) as CreatureEntity;
            if(_loc9_ == null)
            {
               return;
            }
            _loc9_.networkId = _loc1_;
            _loc9_.networkReplica = true;
            _loc9_.level = _loc5_;
            _loc9_.health = _loc6_;
            _loc9_.direction = _loc7_;
            Context.world.addCreature(_loc9_);
            this._creaturesById[_loc1_] = _loc9_;
         }
         catch(e:Error)
         {
            setStatus("ENTITY SPAWN ERROR: " + _loc2_);
         }
      }

      private function handleCreatureRemove(param1:ByteArray) : void
      {
         var _loc2_:int = param1.readInt();
         var _loc3_:CreatureEntity = this._creaturesById[_loc2_] as CreatureEntity;
         if(_loc3_ != null && Context.world != null)
         {
            delete this._creaturesById[_loc2_];
            Context.world.removeCreature(_loc3_);
         }
      }

      private function handlePlaceBlock(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:int = param2.readInt();
         var _loc7_:int = param2.readInt();
         if(!this.canPlayerReach(_loc3_,_loc4_,_loc5_))
         {
            return;
         }
         var _loc8_:ItemStack = _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex];
         if(_loc8_ == null || _loc8_.item.id != _loc6_ || _loc8_.count <= 0 || !(_loc8_.item is BlockItem))
         {
            this.sendInventorySync(_loc3_.networkPlayerId);
            return;
         }
         var _loc9_:BlockItem = _loc8_.item as BlockItem;
         var _loc10_:Boolean = _loc9_.hasDirection ? _loc9_.canPlaceDir(_loc4_,_loc5_,_loc7_) : _loc9_.canPlace(_loc4_,_loc5_);
         if(!_loc10_)
         {
            return;
         }
         --_loc8_.count;
         if(_loc8_.count <= 0)
         {
            _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex] = null;
         }
         if(_loc9_.hasDirection)
         {
            _loc9_.setItemDir(_loc4_,_loc5_,_loc7_);
         }
         else
         {
            _loc9_.setItem(_loc4_,_loc5_);
         }
         _loc3_.handAnimation();
         this.hostWorldChanged(_loc4_,_loc5_);
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function handleBeginDestroy(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive || Context.world == null || Context.game == null)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:int = param2.readInt();
         if(_loc4_ != 1 && _loc4_ != 2 || !this.canPlayerReach(_loc3_,_loc5_,_loc6_) || _loc5_ < 0 || _loc6_ < 0 || _loc5_ >= Context.world.tilesX || _loc6_ >= Context.world.tilesY)
         {
            return;
         }
         var _loc7_:Tile = Context.world.tiles[_loc5_ + _loc6_ * Context.world.tilesX];
         var _loc8_:ItemStack = _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex];
         var _loc9_:int = _loc8_ == null || _loc8_.item == null ? 0 : _loc8_.item.id;
         var _loc10_:Number = 0;
         var _loc11_:int = 0;
         if(_loc4_ == 1)
         {
            if(_loc7_.blockId == 0)
            {
               return;
            }
            var _loc12_:Block = Block.BLOCKS[_loc7_.blockId];
            if(_loc12_ == null || _loc12_.strength == Number.MAX_VALUE || !Context.game.controller.canDestroyBlock(_loc5_,_loc6_,_loc12_,_loc7_.blockData))
            {
               return;
            }
            if(_loc8_ != null && _loc8_.item is MiningItem)
            {
               _loc10_ = MiningItem(_loc8_.item).getBaseDestroy(_loc12_);
            }
            if(_loc10_ == 0)
            {
               _loc10_ = Context.game.controller.canMiningByHand(_loc12_.material) ? 1 : 0.6;
            }
            if(_loc12_ is OreBlock && _loc10_ <= 1)
            {
               return;
            }
            var _loc13_:Number = _loc10_ - _loc12_.strength;
            if(_loc13_ < 0)
            {
               _loc13_ = -_loc13_;
               _loc13_ = 1 - _loc13_ / 10;
            }
            else if(_loc13_ > 0)
            {
               _loc13_ += 1 + _loc13_ / 10;
            }
            else
            {
               _loc13_ = 1;
            }
            var _loc14_:Number = _loc10_ * _loc13_ * 0.35;
            if(_loc14_ <= 0)
            {
               return;
            }
            _loc11_ = Math.max(Core.FRAME_RATE,Math.ceil(_loc12_.strength / _loc14_) * Core.FRAME_RATE);
            this._destroySessions[_loc3_.networkPlayerId] = {
               "kind":1,
               "x":_loc5_,
               "y":_loc6_,
               "targetId":_loc7_.blockId,
               "itemId":_loc9_,
               "started":getTimer(),
               "duration":_loc11_
            };
         }
         else
         {
            if(_loc7_.wallId == 0 || _loc8_ == null || !(_loc8_.item is HammerItem))
            {
               return;
            }
            var _loc15_:Wall = Wall.WALLS[_loc7_.wallId];
            if(_loc15_ == null || _loc15_.bedrock || !Context.game.controller.canDestroyWall(_loc5_,_loc6_,_loc15_))
            {
               return;
            }
            _loc10_ = HammerItem(_loc8_.item).getDestroyWall(_loc15_);
            if(_loc10_ <= 0)
            {
               return;
            }
            _loc11_ = Math.max(Core.FRAME_RATE,Math.ceil(_loc15_.strength / (_loc10_ * 0.5)) * Core.FRAME_RATE);
            this._destroySessions[_loc3_.networkPlayerId] = {
               "kind":2,
               "x":_loc5_,
               "y":_loc6_,
               "targetId":_loc7_.wallId,
               "itemId":_loc9_,
               "started":getTimer(),
               "duration":_loc11_
            };
         }
      }

      private function validateDestroySession(param1:RemotePlayerEntity, param2:int, param3:int, param4:int, param5:int) : Boolean
      {
         var _loc6_:Object = this._destroySessions[param1.networkPlayerId];
         delete this._destroySessions[param1.networkPlayerId];
         if(_loc6_ == null || int(_loc6_.kind) != param2 || int(_loc6_.x) != param3 || int(_loc6_.y) != param4 || int(_loc6_.targetId) != param5)
         {
            return false;
         }
         var _loc7_:ItemStack = param1.inventory.items[param1.inventory.itemInHandIndex];
         var _loc8_:int = _loc7_ == null || _loc7_.item == null ? 0 : _loc7_.item.id;
         if(_loc8_ != int(_loc6_.itemId))
         {
            return false;
         }
         return getTimer() - int(_loc6_.started) + 100 >= int(_loc6_.duration);
      }

      private function handleRemoveBlock(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         if(!this.canPlayerReach(_loc3_,_loc4_,_loc5_) || _loc4_ < 0 || _loc5_ < 0 || _loc4_ >= Context.world.tilesX || _loc5_ >= Context.world.tilesY)
         {
            return;
         }
         var _loc6_:Tile = Context.world.tiles[_loc4_ + _loc5_ * Context.world.tilesX];
         if(_loc6_.blockId == 0)
         {
            return;
         }
         var _loc7_:Block = Block.BLOCKS[_loc6_.blockId];
         if(_loc7_ == null || _loc7_.strength == Number.MAX_VALUE || !Context.game.controller.canDestroyBlock(_loc4_,_loc5_,_loc7_,_loc6_.blockData))
         {
            return;
         }
         if(!this.validateDestroySession(_loc3_,1,_loc4_,_loc5_,_loc6_.blockId))
         {
            return;
         }
         _loc7_.item.removeItem(_loc4_,_loc5_,_loc6_.blockData,true);
         var _loc8_:ItemStack = _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex];
         if(_loc8_ != null && _loc8_.item.destroyable)
         {
            _loc3_.inventory.damageItem(_loc8_);
         }
         _loc3_.handAnimation();
         this.hostWorldChanged(_loc4_,_loc5_);
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function handlePlaceWall(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:int = param2.readInt();
         if(!this.canPlayerReach(_loc3_,_loc4_,_loc5_))
         {
            return;
         }
         var _loc7_:ItemStack = _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex];
         if(_loc7_ == null || _loc7_.item.id != _loc6_ || _loc7_.count <= 0 || !(_loc7_.item is WallItem))
         {
            this.sendInventorySync(_loc3_.networkPlayerId);
            return;
         }
         var _loc8_:WallItem = _loc7_.item as WallItem;
         if(!_loc8_.canPlace(_loc4_,_loc5_))
         {
            return;
         }
         --_loc7_.count;
         if(_loc7_.count <= 0)
         {
            _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex] = null;
         }
         Context.world.setWall(_loc4_,_loc5_,_loc8_.wall);
         _loc3_.handAnimation();
         this.hostWorldChanged(_loc4_,_loc5_);
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function handleRemoveWall(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         if(!this.canPlayerReach(_loc3_,_loc4_,_loc5_) || _loc4_ < 0 || _loc5_ < 0 || _loc4_ >= Context.world.tilesX || _loc5_ >= Context.world.tilesY)
         {
            return;
         }
         var _loc6_:Tile = Context.world.tiles[_loc4_ + _loc5_ * Context.world.tilesX];
         if(_loc6_.wallId == 0)
         {
            return;
         }
         var _loc7_:Wall = Wall.WALLS[_loc6_.wallId];
         if(_loc7_ == null || _loc7_.bedrock || !Context.game.controller.canDestroyWall(_loc4_,_loc5_,_loc7_))
         {
            return;
         }
         if(!this.validateDestroySession(_loc3_,2,_loc4_,_loc5_,_loc6_.wallId))
         {
            return;
         }
         Context.world.removeWall(_loc4_,_loc5_,_loc7_);
         Context.world.dropTileItem(_loc4_,_loc5_,_loc7_.item);
         var _loc8_:ItemStack = _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex];
         if(_loc8_ != null && _loc8_.item.destroyable)
         {
            _loc3_.inventory.damageItem(_loc8_);
         }
         _loc3_.handAnimation();
         this.hostWorldChanged(_loc4_,_loc5_);
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function handleItemPickup(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:Number = param2.readDouble();
         var _loc5_:Number = param2.readDouble();
         var _loc6_:int = param2.readInt();
         var _loc7_:ItemEntity = null;
         var _loc8_:ItemEntity = null;
         var _loc9_:Number = Number.MAX_VALUE;
         var _loc10_:Number = 0;
         var _loc11_:Number = 0;
         var _loc12_:int = 0;
         while(_loc12_ < Context.world.entitiesOnGround.length)
         {
            _loc8_ = Context.world.entitiesOnGround[_loc12_] as ItemEntity;
            if(_loc8_ != null && _loc8_.itemStack != null && _loc8_.itemStack.item.id == _loc6_)
            {
               _loc10_ = _loc8_.position.x - _loc4_;
               _loc11_ = _loc8_.position.y - _loc5_;
               var _loc13_:Number = _loc10_ * _loc10_ + _loc11_ * _loc11_;
               if(_loc13_ < _loc9_)
               {
                  _loc9_ = _loc13_;
                  _loc7_ = _loc8_;
               }
            }
            _loc12_++;
         }
         if(_loc7_ == null || _loc9_ > Tile.SIZE * Tile.SIZE * 4)
         {
            return;
         }
         _loc10_ = _loc3_.center.x - _loc7_.center.x;
         _loc11_ = _loc3_.center.y - _loc7_.center.y;
         if(_loc10_ * _loc10_ + _loc11_ * _loc11_ > Tile.SIZE * Tile.SIZE * 16)
         {
            return;
         }
         if(!_loc3_.inventory.canAdd(_loc7_.itemStack))
         {
            return;
         }
         _loc3_.inventory.add(_loc7_.itemStack);
         _loc12_ = Context.world.entitiesOnGround.indexOf(_loc7_);
         if(_loc12_ >= 0)
         {
            Context.world.entitiesOnGround.splice(_loc12_,1);
            _loc7_.destroy();
         }
         this._dynamicDirty = true;
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function handleDropItem(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive || Context.world == null)
         {
            return;
         }
         var _loc4_:ItemStack = ItemStack.load(param2);
         if(_loc4_ == null || _loc4_.item == null || _loc4_.count <= 0)
         {
            return;
         }
         var _loc5_:ItemStack = null;
         var _loc6_:int = 0;
         while(_loc6_ < _loc3_.inventory.items.length)
         {
            _loc5_ = _loc3_.inventory.items[_loc6_];
            if(_loc5_ != null && _loc5_.item == _loc4_.item && _loc5_.itemData == _loc4_.itemData && _loc5_.count >= _loc4_.count)
            {
               break;
            }
            _loc5_ = null;
            _loc6_++;
         }
         if(_loc5_ == null)
         {
            return;
         }
         var _loc7_:ItemStack = new ItemStack(_loc5_.item,_loc5_.itemData,_loc4_.count);
         _loc3_.inventory.remove(_loc5_.item,_loc4_.count);
         Context.world.entitiesOnGround.push(new ItemEntity(_loc3_.center.x,_loc3_.center.y,_loc7_,ItemEntity.DROP_ACCELERATION_TYPE,_loc3_.direction));
         this._dynamicDirty = true;
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function handleShoot(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive || Context.world == null)
         {
            return;
         }
         var _loc4_:Number = param2.readDouble();
         var _loc5_:Number = param2.readDouble();
         if(isNaN(_loc4_) || isNaN(_loc5_))
         {
            return;
         }
         var _loc6_:int = _loc3_.inventory.itemInHandIndex;
         if(_loc6_ < 0 || _loc6_ >= _loc3_.inventory.items.length)
         {
            return;
         }
         var _loc7_:ItemStack = _loc3_.inventory.items[_loc6_];
         if(_loc7_ == null || !(_loc7_.item is RangedWeaponItem))
         {
            return;
         }
         var _loc8_:RangedWeaponItem = _loc7_.item as RangedWeaponItem;
         var _loc9_:Class = null;
         var _loc10_:int = -1;
         if(_loc8_ is BowItem)
         {
            _loc9_ = ArrowEntity;
            _loc10_ = ArrowItem.ARROW_TYPE;
         }
         else if(_loc8_ is CrossbowItem || _loc8_ is MinicrossbowItem)
         {
            _loc9_ = BoltEntity;
            _loc10_ = ArrowItem.BOLT_TYPE;
         }
         else if(_loc8_ is MiniblasterItem || _loc8_ is BlasterItem)
         {
            _loc9_ = BlasterenergyEntity;
            _loc10_ = ArrowItem.BLASTERENERGY_TYPE;
         }
         else if(_loc8_ is RevolverItem)
         {
            _loc9_ = BulletEntity;
            _loc10_ = ArrowItem.BULLET_TYPE;
         }
         else if(_loc8_ is ShootgunItem)
         {
            _loc9_ = BlasterpoweredenergyEntity;
            _loc10_ = ArrowItem.BLASTERPOWEREDENERGY_TYPE;
         }
         else if(_loc8_ is FlameThrowerItem)
         {
            _loc9_ = FlameEntity;
            _loc10_ = ArrowItem.FUEL_TYPE;
         }
         if(_loc9_ == null)
         {
            return;
         }
         var _loc11_:int = getTimer();
         var _loc12_:Object = this._lastShootTimes[_loc3_.networkPlayerId];
         var _loc13_:int = Math.max(CharacterEntity.HAND_SPEED,_loc8_.speed) * Core.FRAME_RATE;
         if(_loc12_ != null && _loc11_ - int(_loc12_) < _loc13_)
         {
            return;
         }
         var _loc14_:ItemStack = null;
         var _loc15_:int = 0;
         while(_loc15_ < _loc3_.inventory.projectiles.length)
         {
            var _loc16_:ItemStack = _loc3_.inventory.projectiles[_loc15_];
            if(_loc16_ != null && _loc16_.item is ArrowItem && ArrowItem(_loc16_.item).type == _loc10_ && _loc16_.count > 0)
            {
               _loc14_ = _loc16_;
               break;
            }
            _loc15_++;
         }
         if(_loc14_ == null)
         {
            this.sendInventorySync(_loc3_.networkPlayerId);
            return;
         }
         this._lastShootTimes[_loc3_.networkPlayerId] = _loc11_;
         --_loc14_.count;
         if(_loc14_.count <= 0)
         {
            _loc3_.inventory.projectiles[_loc15_] = null;
         }
         var _loc17_:int = 1;
         if(_loc8_ is ShootgunItem)
         {
            _loc17_ = 5;
         }
         else if(_loc8_ is FlameThrowerItem)
         {
            _loc17_ = _loc3_.underliquid ? 0 : 3;
         }
         var _loc18_:int = 0;
         while(_loc18_ < _loc17_)
         {
            var _loc19_:Number = _loc3_.center.x;
            var _loc20_:Number = _loc3_.center.y - 10;
            if(_loc8_ is ShootgunItem)
            {
               _loc19_ += Random.nextInt(-5,5);
               _loc20_ += Random.nextInt(-5,5);
            }
            else if(_loc8_ is FlameThrowerItem)
            {
               _loc19_ += Random.nextInt(-5,5);
               _loc20_ = _loc3_.center.y - 2 + _loc18_ * 2;
            }
            var _loc21_:ProjectileEntity = new _loc9_(_loc19_,_loc20_,_loc8_.strengthShot,_loc14_.item) as ProjectileEntity;
            if(_loc21_ != null)
            {
               _loc21_.setOwner(_loc3_);
               if(_loc8_ is ShootgunItem || _loc8_ is FlameThrowerItem)
               {
                  _loc21_.setVelocityFromPointsShootgun(_loc3_.center.x,_loc3_.center.y,_loc4_,_loc5_,0.2);
               }
               else
               {
                  _loc21_.setVelocityFromPoints(_loc3_.center.x,_loc3_.center.y,_loc4_,_loc5_);
               }
               Context.world.addProjectile(_loc21_);
               this.broadcastProjectileSpawn(_loc21_,_loc3_.networkPlayerId,_loc8_.strengthShot,ArrowItem(_loc14_.item).id);
            }
            _loc18_++;
         }
         _loc3_.handShootAnimation(_loc4_ - Context.screen.x,_loc5_ - Context.screen.y - 20);
         _loc3_.inventory.damageItem(_loc7_);
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function broadcastProjectileSpawn(param1:ProjectileEntity, param2:int, param3:Number, param4:int) : void
      {
         if(this._server == null || param1 == null)
         {
            return;
         }
         var _loc5_:ByteArray = new ByteArray();
         _loc5_.writeUTF(getQualifiedClassName(param1));
         _loc5_.writeInt(param2);
         _loc5_.writeInt(param4);
         _loc5_.writeDouble(param3);
         _loc5_.writeDouble(param1.position.x);
         _loc5_.writeDouble(param1.position.y);
         _loc5_.writeDouble(param1.velocity.x);
         _loc5_.writeDouble(param1.velocity.y);
         this._server.broadcast(MultiplayerProtocol.PROJECTILE_SPAWN,HOST_PLAYER_ID,_loc5_);
      }

      private function handleProjectileSpawn(param1:ByteArray) : void
      {
         var _loc1_:String;
         var _loc2_:int;
         var _loc3_:int;
         var _loc4_:Number;
         var _loc5_:Number;
         var _loc6_:Number;
         var _loc7_:Number;
         var _loc8_:Number;
         var _loc9_:Class;
         var _loc10_:ProjectileEntity;
         if(!this.isClient || Context.world == null)
         {
            return;
         }
         _loc1_ = param1.readUTF();
         _loc2_ = param1.readInt();
         _loc3_ = param1.readInt();
         _loc4_ = param1.readDouble();
         _loc5_ = param1.readDouble();
         _loc6_ = param1.readDouble();
         _loc7_ = param1.readDouble();
         _loc8_ = param1.readDouble();
         if(_loc3_ < 0 || _loc3_ >= Item.ITEMS.length || !(Item.ITEMS[_loc3_] is ArrowItem))
         {
            return;
         }
         try
         {
            _loc9_ = getDefinitionByName(_loc1_) as Class;
            _loc10_ = new _loc9_(_loc5_,_loc6_,_loc4_,Item.ITEMS[_loc3_]) as ProjectileEntity;
            if(_loc10_ == null)
            {
               return;
            }
            _loc10_.networkReplica = true;
            _loc10_.setOwner(this.getClientCreatureByNetworkId(_loc2_));
            _loc10_.velocity.x = _loc7_;
            _loc10_.velocity.y = _loc8_;
            Context.world.addProjectile(_loc10_);
         }
         catch(e:Error)
         {
            this.setStatus("PROJECTILE SPAWN ERROR: " + e.message);
         }
      }

      private function handleConsume(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:int = _loc3_.inventory.itemInHandIndex;
         if(_loc6_ < 0 || _loc6_ >= _loc3_.inventory.items.length)
         {
            return;
         }
         var _loc7_:ItemStack = _loc3_.inventory.items[_loc6_];
         if(_loc7_ == null || _loc7_.item == null || _loc7_.item.id != _loc4_ || _loc7_.itemData != _loc5_ || _loc7_.count <= 0 || !(_loc7_.item is ConsumableItem))
         {
            this.sendInventorySync(_loc3_.networkPlayerId);
            return;
         }
         var _loc8_:ConsumableItem = _loc7_.item as ConsumableItem;
         if(_loc3_.level < _loc8_.requiredLevel)
         {
            return;
         }
         var _loc9_:int = getTimer();
         var _loc10_:Object = this._lastConsumeTimes[_loc3_.networkPlayerId];
         var _loc11_:int = Math.max(CharacterEntity.HAND_SPEED,_loc8_.speed) * Core.FRAME_RATE;
         if(_loc10_ != null && _loc9_ - int(_loc10_) < _loc11_)
         {
            return;
         }
         if(_loc8_.healing)
         {
            if(_loc3_.health >= _loc3_.maxHealth || _loc3_.hasBuff(Buff.healing))
            {
               return;
            }
            var _loc12_:int = 60;
            if(_loc8_ is HealingPotionItem)
            {
               _loc12_ = HealingPotionItem(_loc8_).healingTime;
            }
            _loc3_.addBuff(Buff.healing,_loc12_);
         }
         this._lastConsumeTimes[_loc3_.networkPlayerId] = _loc9_;
         --_loc7_.count;
         _loc8_.consumable(_loc3_);
         _loc3_.handAnimation();
         if(_loc7_.count <= 0)
         {
            _loc3_.inventory.items[_loc6_] = null;
         }
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      public function notifyPvpBlocked() : void
      {
         var _loc1_:int = getTimer();
         if(_loc1_ - this._lastPvpBlockedNotice > 3500)
         {
            this._lastPvpBlockedNotice = _loc1_;
            this.systemMessage(this.isRussian ? "[PvP] Урон заблокирован: для боя ОБА игрока должны включить PvP!" : "[PvP] Attack blocked: BOTH players must have PvP enabled!");
         }
      }

      private function handlePvpStateRequest(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:Object = this._connectionIds[param1];
         if(_loc3_ == null || param2 == null || param2.bytesAvailable < 1)
         {
            return;
         }
         var _loc4_:int = int(_loc3_);
         var _loc5_:Boolean = param2.readBoolean();
         this._pvpPlayers[_loc4_] = _loc5_;
         this.broadcastPvpState(_loc4_,_loc5_);
         var _locNick_:String = this.playerNick(_loc4_);
         this.systemMessage((this.isRussian ? "[PvP] Игрок " : "[PvP] Player ") + _locNick_ + (this.isRussian ? (_loc5_ ? ": PvP ВКЛЮЧЁН (готов к бою)" : ": PvP ВЫКЛЮЧЕН (мирный)") : (_loc5_ ? ": PvP ON" : ": PvP OFF")));
      }

      private function handleAttack(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:CreatureEntity = this.getCreatureByNetworkId(_loc4_);
         if(_loc5_ == null || !_loc5_.alive || _loc5_ == _loc3_)
         {
            return;
         }
         if(this.isNetworkPlayer(_loc5_) && !this.isPvpPlayerAttack(_loc3_,_loc5_))
         {
            return;
         }
         var _loc6_:Number = _loc3_.center.x - _loc5_.center.x;
         var _loc7_:Number = _loc3_.center.y - _loc5_.center.y;
         if(_loc6_ * _loc6_ + _loc7_ * _loc7_ > INTERACT_RADIUS * INTERACT_RADIUS)
         {
            return;
         }
         var _loc8_:int = CharacterEntity.HAND_DAMAGE;
         var _loc9_:Number = CharacterEntity.HAND_CRIT;
         var _loc10_:int = CharacterEntity.HAND_KNOCKBACK;
         var _loc11_:ItemStack = _loc3_.inventory.items[_loc3_.inventory.itemInHandIndex];
         var _loc12_:int = CharacterEntity.HAND_SPEED * Core.FRAME_RATE;
         if(_loc11_ != null && _loc11_.item.canUseInHand)
         {
            _loc12_ = Math.max(1,_loc11_.item.speed) * Core.FRAME_RATE;
         }
         var _loc13_:int = getTimer();
         var _loc14_:Object = this._lastAttackTimes[_loc3_.networkPlayerId];
         if(_loc14_ != null && _loc13_ - int(_loc14_) < _loc12_)
         {
            return;
         }
         this._lastAttackTimes[_loc3_.networkPlayerId] = _loc13_;
         if(_loc11_ != null && _loc11_.item.canUseInHand)
         {
            _loc8_ = _loc11_.item.damage + _loc3_.inventory.getModifier(Ability.DAMAGE);
            _loc9_ = Math.max(0,_loc11_.item.crit + _loc3_.inventory.getModifier(Ability.CRIT));
            _loc10_ = _loc11_.item.knockback;
         }
         if(Random.probability() < _loc9_)
         {
            _loc8_ *= 2;
         }
         _loc5_.creatureAttacking(_loc8_,_loc3_);
         _loc5_.addVelocity(Knockback.toVelocity(_loc10_),_loc3_.direction);
         _loc3_.handAnimation();
         if(_loc11_ != null && _loc11_.item.destroyable)
         {
            _loc3_.inventory.damageItem(_loc11_);
            this.sendInventorySync(_loc3_.networkPlayerId);
         }
      }

      private function getClientCreatureByNetworkId(param1:int) : CreatureEntity
      {
         if(Context.world == null)
         {
            return null;
         }
         if(param1 == this._localPlayerId)
         {
            return Context.world.player;
         }
         var _loc2_:RemotePlayerEntity = this._remotePlayers[param1] as RemotePlayerEntity;
         if(_loc2_ != null)
         {
            return _loc2_;
         }
         return this._creaturesById[param1] as CreatureEntity;
      }

      private function getCreatureByNetworkId(param1:int) : CreatureEntity
      {
         if(param1 == HOST_PLAYER_ID)
         {
            return Context.world == null ? null : Context.world.player;
         }
         var _loc2_:RemotePlayerEntity = this._remotePlayers[param1] as RemotePlayerEntity;
         if(_loc2_ != null)
         {
            return _loc2_;
         }
         return this._creaturesById[param1] as CreatureEntity;
      }

      private function getConnectionPlayer(param1:NetworkConnection) : RemotePlayerEntity
      {
         var _loc2_:Object = this._connectionIds[param1];
         if(_loc2_ == null)
         {
            return null;
         }
         return this._remotePlayers[int(_loc2_)] as RemotePlayerEntity;
      }

      private function canPlayerReach(param1:CreatureEntity, param2:int, param3:int) : Boolean
      {
         if(Context.world == null || param2 < 0 || param3 < 0 || param2 >= Context.world.tilesX || param3 >= Context.world.tilesY)
         {
            return false;
         }
         var _loc4_:Number = param2 * Tile.SIZE + Tile.HALF_SIZE - param1.center.x;
         var _loc5_:Number = param3 * Tile.SIZE + Tile.HALF_SIZE - param1.center.y;
         return _loc4_ * _loc4_ + _loc5_ * _loc5_ <= INTERACT_RADIUS * INTERACT_RADIUS;
      }

      private function broadcastTilePatch(param1:int, param2:int, param3:int) : void
      {
         if(this._server == null || Context.world == null)
         {
            return;
         }
         var _loc4_:int = Math.max(0,param1 - param3);
         var _loc5_:int = Math.min(Context.world.tilesX - 1,param1 + param3);
         var _loc6_:int = Math.max(0,param2 - param3);
         var _loc7_:int = Math.min(Context.world.tilesY - 1,param2 + param3);
         var _loc8_:ByteArray = new ByteArray();
         _loc8_.writeInt((_loc5_ - _loc4_ + 1) * (_loc7_ - _loc6_ + 1));
         var _loc9_:int = _loc4_;
         var _loc10_:int = 0;
         var _loc11_:Tile = null;
         while(_loc9_ <= _loc5_)
         {
            _loc10_ = _loc6_;
            while(_loc10_ <= _loc7_)
            {
               _loc11_ = Context.world.tiles[_loc9_ + _loc10_ * Context.world.tilesX];
               _loc8_.writeInt(_loc9_);
               _loc8_.writeInt(_loc10_);
               _loc8_.writeInt(_loc11_.data);
               _loc8_.writeInt(_loc11_.additionalData);
               _loc10_++;
            }
            _loc9_++;
         }
         this._server.broadcast(MultiplayerProtocol.TILE_PATCH,HOST_PLAYER_ID,_loc8_);
      }

      private function broadcastDynamicWorldState() : void
      {
         if(this._server == null || Context.world == null)
         {
            return;
         }
         var _loc1_:ByteArray = new ByteArray();
         Context.world.saveNetworkDynamicState(_loc1_);
         _loc1_.position = 0;
         this._server.broadcast(MultiplayerProtocol.DYNAMIC_WORLD_STATE,HOST_PLAYER_ID,_loc1_);
      }

      private function sendInventorySync(param1:int) : void
      {
         if(this._server == null || Context.game == null)
         {
            return;
         }
         var _loc2_:CharacterInventory = null;
         var _loc3_:int = 0;
         if(param1 == HOST_PLAYER_ID)
         {
            _loc2_ = Context.game.inventory;
            _loc3_ = Context.game.controller.selectedItemIndex;
         }
         else
         {
            var _loc4_:RemotePlayerEntity = this._remotePlayers[param1] as RemotePlayerEntity;
            if(_loc4_ == null)
            {
               return;
            }
            _loc2_ = _loc4_.inventory;
            _loc3_ = _loc4_.inventory.itemInHandIndex;
         }
         var _loc5_:Object = new Object();
         _loc2_.save(_loc5_);
         var _loc6_:ByteArray = new ByteArray();
         _loc6_.writeInt(param1);
         _loc6_.writeObject(_loc5_);
         _loc6_.writeInt(_loc3_);
         this._server.broadcast(MultiplayerProtocol.INVENTORY_SYNC,HOST_PLAYER_ID,_loc6_);
      }

      private function broadcastAllInventoryStates() : void
      {
         if(this._server == null || Context.game == null)
         {
            return;
         }
         this.sendInventorySync(HOST_PLAYER_ID);
         var _loc1_:RemotePlayerEntity = null;
         for each(_loc1_ in this._remotePlayers)
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
         }
      }

      private function handleInventorySync(param1:ByteArray) : void
      {
         if(Context.game == null)
         {
            return;
         }
         var _loc2_:int = param1.readInt();
         var _loc3_:Object = param1.readObject();
         var _loc4_:int = param1.readInt();
         if(_loc2_ == this._localPlayerId)
         {
            Context.game.inventory.load(_loc3_);
            Context.game.controller.selectedItemIndex = _loc4_;
            Context.game.inventory.itemInHandIndex = _loc4_;
            return;
         }
         var _loc5_:RemotePlayerEntity = this._remotePlayers[_loc2_] as RemotePlayerEntity;
         if(_loc5_ != null)
         {
            _loc5_.inventory.load(_loc3_);
            _loc5_.inventory.itemInHandIndex = _loc4_;
         }
      }

      private function sendInventoryLayout() : void
      {
         if(!this.isClient || this._client == null || Context.game == null)
         {
            return;
         }
         var _loc1_:Object = new Object();
         Context.game.inventory.save(_loc1_);
         var _loc2_:ByteArray = new ByteArray();
         _loc2_.writeObject(_loc1_);
         _loc2_.writeInt(Context.game.controller.selectedItemIndex);
         this._client.send(MultiplayerProtocol.REQUEST_INVENTORY_LAYOUT,this._localPlayerId,_loc2_);
      }

      private function getTileInventoryItems(param1:TileEntity) : Vector.<ItemStack>
      {
         if(param1 is BaseChestTileEntity)
         {
            return BaseChestTileEntity(param1).items;
         }
         if(param1 is BurnerTileEntity)
         {
            return BurnerTileEntity(param1).items;
         }
         if(param1 is FurnaceTileEntity)
         {
            return FurnaceTileEntity(param1).items;
         }
         if(param1 is RobotPanelTileEntity)
         {
            return RobotPanelTileEntity(param1).items;
         }
         return null;
      }

      private function sameStack(param1:ItemStack, param2:ItemStack) : Boolean
      {
         if(param1 == null || param2 == null)
         {
            return param1 == param2;
         }
         return param1.item == param2.item && param1.itemData == param2.itemData && param1.count == param2.count;
      }

      private function validTileInventoryLayout(param1:TileEntity, param2:Vector.<ItemStack>, param3:Vector.<ItemStack>) : Boolean
      {
         if(param1 is FurnaceTileEntity)
         {
            if(param3.length != 3)
            {
               return false;
            }
            if(param3[FurnaceTileEntity.INGREDIENT_ITEM_INDEX] != null && !FurnaceTileEntity.isIngredient(param3[FurnaceTileEntity.INGREDIENT_ITEM_INDEX].item))
            {
               return false;
            }
            if(param3[FurnaceTileEntity.FUEL_ITEM_INDEX] != null && !FurnaceTileEntity.isFuel(param3[FurnaceTileEntity.FUEL_ITEM_INDEX].item))
            {
               return false;
            }
            var _loc4_:ItemStack = param2[FurnaceTileEntity.RESULT_ITEM_INDEX];
            var _loc5_:ItemStack = param3[FurnaceTileEntity.RESULT_ITEM_INDEX];
            if(_loc5_ != null)
            {
               if(_loc4_ == null || _loc4_.item != _loc5_.item || _loc4_.itemData != _loc5_.itemData || _loc5_.count > _loc4_.count)
               {
                  return false;
               }
            }
            return true;
         }
         if(param1 is RobotPanelTileEntity)
         {
            var _loc6_:int = 1;
            while(_loc6_ < param2.length)
            {
               if(!this.sameStack(param2[_loc6_],param3[_loc6_]))
               {
                  return false;
               }
               _loc6_++;
            }
            return true;
         }
         return true;
      }

      private function handleTileAction(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive || Context.world == null)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:int = param2.readInt();
         var _loc7_:int = param2.readInt();
         var _loc8_:TileEntity = Context.world.getTileEntity(_loc4_,_loc5_);
         if(_loc8_ == null || _loc8_.type != _loc6_ || !this.canPlayerReach(_loc3_,_loc4_,_loc5_))
         {
            return;
         }
         if(_loc7_ == 1 && _loc8_ is BurnerTileEntity)
         {
            BurnerTileEntity(_loc8_).clear();
            this._dynamicDirty = true;
         }
         else if(_loc7_ == 2 && _loc8_ is RobotPanelTileEntity)
         {
            var _loc9_:RobotPanelTileEntity = RobotPanelTileEntity(_loc8_);
            if(_loc9_.items[0] != null && _loc9_.items[0].item == Item.BATTERY)
            {
               _loc9_.clear();
               this._dynamicDirty = true;
            }
         }
      }

      private function handleTreasureChestOpen(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive || Context.world == null)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:TreasureChestTileEntity = Context.world.getTileEntity(_loc4_,_loc5_) as TreasureChestTileEntity;
         var _loc7_:Boolean = false;
         if(_loc6_ != null && this.canPlayerReach(_loc3_,_loc4_,_loc5_))
         {
            if(_loc6_.isOpen())
            {
               _loc7_ = true;
            }
            else if(_loc3_.inventory.contains(Item.TREASURE_KEY))
            {
               _loc3_.inventory.remove(Item.TREASURE_KEY,1);
               _loc6_.open();
               _loc7_ = true;
               this.sendInventorySync(_loc3_.networkPlayerId);
               this._dynamicDirty = true;
            }
         }
         var _loc8_:ByteArray = new ByteArray();
         _loc8_.writeInt(_loc4_);
         _loc8_.writeInt(_loc5_);
         _loc8_.writeBoolean(_loc7_);
         param1.send(MultiplayerProtocol.TREASURE_OPEN_RESULT,HOST_PLAYER_ID,_loc8_);
      }

      private function handleTreasureOpenResult(param1:ByteArray) : void
      {
         if(Context.world == null || Context.game == null)
         {
            return;
         }
         var _loc2_:int = param1.readInt();
         var _loc3_:int = param1.readInt();
         var _loc4_:Boolean = param1.readBoolean();
         if(!_loc4_)
         {
            this.setStatus("TREASURE CHEST LOCKED");
            return;
         }
         var _loc5_:TreasureChestTileEntity = Context.world.getTileEntity(_loc2_,_loc3_) as TreasureChestTileEntity;
         if(_loc5_ != null)
         {
            if(!_loc5_.isOpen())
            {
               _loc5_.open();
            }
            Context.game.showInventory_TreasureChest(_loc5_);
         }
      }

      private function sendTileInventoryLayout(param1:TileEntity) : void
      {
         if(!this.isClient || this._client == null || Context.game == null || param1 == null || this.getTileInventoryItems(param1) == null)
         {
            return;
         }
         var _loc2_:Object = new Object();
         Context.game.inventory.save(_loc2_);
         var _loc3_:ByteArray = new ByteArray();
         _loc3_.writeInt(param1.x);
         _loc3_.writeInt(param1.y);
         _loc3_.writeInt(param1.type);
         _loc3_.writeObject(_loc2_);
         _loc3_.writeInt(Context.game.controller.selectedItemIndex);
         var _loc4_:Vector.<ItemStack> = this.getTileInventoryItems(param1);
         _loc3_.writeInt(_loc4_.length);
         var _loc5_:int = 0;
         while(_loc5_ < _loc4_.length)
         {
            ItemStack.save(_loc3_,_loc4_[_loc5_]);
            _loc5_++;
         }
         this._client.send(MultiplayerProtocol.REQUEST_CHEST_LAYOUT,this._localPlayerId,_loc3_);
      }

      private function handleChestLayout(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc2_:int;
         var _loc3_:int;
         var _loc4_:int;
         var _loc5_:Object;
         var _loc6_:int;
         var _loc7_:int;
         var _loc8_:TileEntity;
         var _loc14_:Vector.<ItemStack>;
         var _loc9_:CharacterInventory;
         var _loc10_:Vector.<ItemStack>;
         var _loc11_:int;
         var _loc12_:Object;
         var _loc13_:Object;
         var _loc1_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc1_ == null || !_loc1_.alive || Context.world == null)
         {
            return;
         }
         try
         {
            _loc2_ = param2.readInt();
            _loc3_ = param2.readInt();
            _loc4_ = param2.readInt();
            _loc5_ = param2.readObject();
            _loc6_ = param2.readInt();
            _loc7_ = param2.readInt();
         }
         catch(e:Error)
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         _loc8_ = Context.world.getTileEntity(_loc2_,_loc3_);
         _loc14_ = this.getTileInventoryItems(_loc8_);
         if(_loc8_ == null || _loc8_.type != _loc4_ || _loc14_ == null || _loc7_ != _loc14_.length || _loc7_ < 0 || _loc7_ > 64 || !this.canPlayerReach(_loc1_,_loc2_,_loc3_))
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         _loc9_ = new CharacterInventory();
         try
         {
            _loc9_.load(_loc5_);
         }
         catch(e2:Error)
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         if(_loc6_ < 0 || _loc6_ >= CharacterInventory.ITEMS_COUNT || !this.validInventorySlotTypes(_loc9_,_loc1_.level) || !this.validInventoryStacks(_loc9_))
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         _loc10_ = new Vector.<ItemStack>(_loc7_,true);
         _loc11_ = 0;
         try
         {
            while(_loc11_ < _loc7_)
            {
               _loc10_[_loc11_] = ItemStack.load(param2);
               _loc11_++;
            }
         }
         catch(e3:Error)
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         if(!this.validItemVector(_loc10_) || !this.validTileInventoryLayout(_loc8_,_loc14_,_loc10_))
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            this._dynamicDirty = true;
            return;
         }
         _loc12_ = this.inventoryMultiset(_loc1_.inventory);
         this.addInventoryVectorToMultiset(_loc12_,_loc14_);
         _loc13_ = this.inventoryMultiset(_loc9_);
         this.addInventoryVectorToMultiset(_loc13_,_loc10_);
         if(!this.sameMultisetObjects(_loc12_,_loc13_))
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            this._dynamicDirty = true;
            return;
         }
         _loc1_.inventory.load(_loc5_);
         _loc1_.inventory.itemInHandIndex = _loc6_;
         _loc11_ = 0;
         while(_loc11_ < _loc14_.length)
         {
            _loc14_[_loc11_] = _loc10_[_loc11_];
            _loc11_++;
         }
         this.sendInventorySync(_loc1_.networkPlayerId);
         this._dynamicDirty = true;
      }

      private function handleInventoryLayout(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc2_:Object;
         var _loc3_:int;
         var _loc4_:CharacterInventory;
         var _loc1_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc1_ == null)
         {
            return;
         }
         _loc2_ = null;
         _loc3_ = 0;
         try
         {
            _loc2_ = param2.readObject();
            _loc3_ = param2.readInt();
         }
         catch(e:Error)
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         _loc4_ = new CharacterInventory();
         try
         {
            _loc4_.load(_loc2_);
         }
         catch(e2:Error)
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         if(_loc3_ < 0 || _loc3_ >= CharacterInventory.ITEMS_COUNT || !this.validInventorySlotTypes(_loc4_,_loc1_.level) || !this.sameInventoryMultiset(_loc1_.inventory,_loc4_))
         {
            this.sendInventorySync(_loc1_.networkPlayerId);
            return;
         }
         _loc1_.inventory.load(_loc2_);
         _loc1_.inventory.itemInHandIndex = _loc3_;
         this.sendInventorySync(_loc1_.networkPlayerId);
      }

      private function validInventorySlotTypes(param1:CharacterInventory, param2:int) : Boolean
      {
         var _loc3_:ItemStack = param1.armors[CharacterInventory.HEAD_ARMOR_INDEX];
         var _loc4_:ItemStack = param1.armors[CharacterInventory.BODY_ARMOR_INDEX];
         var _loc5_:ItemStack = param1.armors[CharacterInventory.LEGS_ARMOR_INDEX];
         if(_loc3_ != null && (!(_loc3_.item is HeadArmorItem) || ArmorItem(_loc3_.item).clothing || _loc3_.item.requiredLevel > param2))
         {
            return false;
         }
         if(_loc4_ != null && (!(_loc4_.item is BodyArmorItem) || ArmorItem(_loc4_.item).clothing || _loc4_.item.requiredLevel > param2))
         {
            return false;
         }
         if(_loc5_ != null && (!(_loc5_.item is LegsArmorItem) || ArmorItem(_loc5_.item).clothing || _loc5_.item.requiredLevel > param2))
         {
            return false;
         }
         _loc3_ = param1.socialArmors[CharacterInventory.HEAD_SOCIAL_ARMOR_INDEX];
         _loc4_ = param1.socialArmors[CharacterInventory.BODY_SOCIAL_ARMOR_INDEX];
         _loc5_ = param1.socialArmors[CharacterInventory.LEGS_SOCIAL_ARMOR_INDEX];
         if(_loc3_ != null && (!(_loc3_.item is HeadArmorItem) || _loc3_.item.requiredLevel > param2))
         {
            return false;
         }
         if(_loc4_ != null && (!(_loc4_.item is BodyArmorItem) || _loc4_.item.requiredLevel > param2))
         {
            return false;
         }
         if(_loc5_ != null && (!(_loc5_.item is LegsArmorItem) || _loc5_.item.requiredLevel > param2))
         {
            return false;
         }
         var _loc6_:int = 0;
         while(_loc6_ < param1.projectiles.length)
         {
            if(param1.projectiles[_loc6_] != null && !(param1.projectiles[_loc6_].item is ProjectileItem))
            {
               return false;
            }
            _loc6_++;
         }
         return true;
      }

      private function validInventoryStacks(param1:CharacterInventory) : Boolean
      {
         return this.validItemVector(param1.items) && this.validItemVector(param1.armors) && this.validItemVector(param1.socialArmors) && this.validItemVector(param1.projectiles);
      }

      private function validItemVector(param1:Vector.<ItemStack>) : Boolean
      {
         var _loc2_:ItemStack = null;
         for each(_loc2_ in param1)
         {
            if(_loc2_ != null && (_loc2_.item == null || _loc2_.count <= 0))
            {
               return false;
            }
         }
         return true;
      }

      private function sameMultisetObjects(param1:Object, param2:Object) : Boolean
      {
         var _loc3_:String = null;
         for(_loc3_ in param1)
         {
            if(param2[_loc3_] === undefined || int(param2[_loc3_]) != int(param1[_loc3_]))
            {
               return false;
            }
         }
         for(_loc3_ in param2)
         {
            if(param1[_loc3_] === undefined || int(param1[_loc3_]) != int(param2[_loc3_]))
            {
               return false;
            }
         }
         return true;
      }

      private function sameInventoryMultiset(param1:CharacterInventory, param2:CharacterInventory) : Boolean
      {
         return this.sameMultisetObjects(this.inventoryMultiset(param1),this.inventoryMultiset(param2));
      }

      private function inventoryMultiset(param1:CharacterInventory) : Object
      {
         var _loc2_:Object = new Object();
         this.addInventoryVectorToMultiset(_loc2_,param1.items);
         this.addInventoryVectorToMultiset(_loc2_,param1.armors);
         this.addInventoryVectorToMultiset(_loc2_,param1.socialArmors);
         this.addInventoryVectorToMultiset(_loc2_,param1.projectiles);
         return _loc2_;
      }

      private function addInventoryVectorToMultiset(param1:Object, param2:Vector.<ItemStack>) : void
      {
         var _loc3_:ItemStack = null;
         var _loc4_:String = null;
         for each(_loc3_ in param2)
         {
            if(!(_loc3_ == null || _loc3_.item == null || _loc3_.count <= 0))
            {
               _loc4_ = _loc3_.item.id + ":" + _loc3_.itemData;
               if(param1[_loc4_] === undefined)
               {
                  param1[_loc4_] = 0;
               }
               param1[_loc4_] = int(param1[_loc4_]) + _loc3_.count;
            }
         }
      }

      private function handleCraft(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:int = param2.readInt();
         var _loc7_:int = param2.readInt();
         var _loc8_:int = param2.readInt();
         var _loc9_:Recipe = this.findRecipe(_loc4_,_loc5_,_loc7_,_loc8_);
         if(_loc9_ == null || !this.recipeAllowedAtUtility(_loc9_.requiredUtility,_loc6_) || !this.isPlayerNearCraftUtility(_loc3_,_loc6_))
         {
            this.sendInventorySync(_loc3_.networkPlayerId);
            return;
         }
         var _loc10_:Ingredient = null;
         for each(_loc10_ in _loc9_.ingredients)
         {
            if(!_loc3_.inventory.contains(_loc10_.item,_loc10_.count))
            {
               this.sendInventorySync(_loc3_.networkPlayerId);
               return;
            }
         }
         if(!_loc3_.inventory.canAdd(_loc9_.craftedItem))
         {
            this.sendInventorySync(_loc3_.networkPlayerId);
            return;
         }
         for each(_loc10_ in _loc9_.ingredients)
         {
            _loc3_.inventory.remove(_loc10_.item,_loc10_.count);
         }
         _loc3_.inventory.add(_loc9_.craftedItem.clone());
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function findRecipe(param1:int, param2:int, param3:int, param4:int) : Recipe
      {
         var _loc5_:Vector.<Recipe> = this.recipesForCategory(param1);
         var _loc6_:Recipe = null;
         if(_loc5_ == null)
         {
            return null;
         }
         for each(_loc6_ in _loc5_)
         {
            if(_loc6_.requiredUtility == param2 && _loc6_.craftedItem != null && _loc6_.craftedItem.item != null && _loc6_.craftedItem.item.id == param3 && _loc6_.craftedItem.count == param4)
            {
               return _loc6_;
            }
         }
         return null;
      }

      private function recipesForCategory(param1:int) : Vector.<Recipe>
      {
         switch(param1)
         {
            case Recipe.BLOCKS_CATEGORY:
               return Recipe.BLOCKS;
            case Recipe.DECORS_CATEGORY:
               return Recipe.DECORS;
            case Recipe.TOOLS_CATEGORY:
               return Recipe.TOOLS;
            case Recipe.ARMORS_CATEGORY:
               return Recipe.ARMORS;
            case Recipe.WEAPONS_CATEGORY:
               return Recipe.WEAPONS;
            case Recipe.CONSUMABLES_CATEGORY:
               return Recipe.CONSUMABLES;
            case Recipe.MACHINERY_CATEGORY:
               return Recipe.MACHINERY;
            case Recipe.SHOP_CATEGORY:
               return Recipe.SHOP;
            case Recipe.TECHNO_WORKBENCH_CATEGORY:
               return Recipe.TECHNOWORKBENCH;
            default:
               return null;
         }
      }

      private function recipeAllowedAtUtility(param1:int, param2:int) : Boolean
      {
         return param1 == param2 || param1 == Recipe.HAND_UTILITY || param1 == Recipe.WORKBENCH_UTILITY && param2 == Recipe.TECHNO_WORKBENCH_UTILITY || param1 == Recipe.ANVIL_UTILITY && param2 == Recipe.TECHNO_WORKBENCH_UTILITY || param1 == Recipe.ALCHEMICAL_TABLE_UTILITY && param2 == Recipe.MECHANICAL_UTILITY;
      }

      private function isPlayerNearCraftUtility(param1:RemotePlayerEntity, param2:int) : Boolean
      {
         if(param2 == Recipe.HAND_UTILITY)
         {
            return true;
         }
         if(Context.world == null)
         {
            return false;
         }
         var _loc3_:Block = null;
         switch(param2)
         {
            case Recipe.WORKBENCH_UTILITY:
               _loc3_ = Block.WORKBENCH;
               break;
            case Recipe.ANVIL_UTILITY:
               _loc3_ = Block.ANVIL;
               break;
            case Recipe.ALCHEMICAL_TABLE_UTILITY:
               _loc3_ = Block.ALCHEMICAL_TABLE;
               break;
            case Recipe.MECHANICAL_UTILITY:
               _loc3_ = Block.WORKSHOP;
               break;
            case Recipe.SHOP_UTILITY:
               _loc3_ = Block.SHOP;
               break;
            case Recipe.TECHNO_WORKBENCH_UTILITY:
               _loc3_ = Block.TECHNO_WORKBENCH;
               break;
            default:
               return false;
         }
         if(_loc3_ == null)
         {
            return false;
         }
         var _loc4_:int = int(param1.center.x / Tile.SIZE);
         var _loc5_:int = int(param1.center.y / Tile.SIZE);
         var _loc6_:int = Math.ceil(INTERACT_RADIUS / Tile.SIZE);
         var _loc7_:int = Math.max(0,_loc4_ - _loc6_);
         var _loc8_:int = Math.min(Context.world.tilesX - 1,_loc4_ + _loc6_);
         var _loc9_:int = Math.max(0,_loc5_ - _loc6_);
         var _loc10_:int = Math.min(Context.world.tilesY - 1,_loc5_ + _loc6_);
         var _loc12_:int = _loc9_;
         loop0:
         while(true)
         {
            if(_loc12_ > _loc10_)
            {
               return false;
            }
            var _loc11_:int = _loc7_;
            while(true)
            {
               if(_loc11_ > _loc8_)
               {
                  break;
               }
               var _loc13_:Tile = Context.world.tiles[_loc11_ + _loc12_ * Context.world.tilesX];
               if(_loc13_.blockId == _loc3_.id)
               {
                  var _loc14_:Number = param1.center.x - (_loc11_ * Tile.SIZE + Tile.HALF_SIZE);
                  var _loc15_:Number = param1.center.y - (_loc12_ * Tile.SIZE + Tile.HALF_SIZE);
                  if(_loc14_ * _loc14_ + _loc15_ * _loc15_ <= INTERACT_RADIUS * INTERACT_RADIUS)
                  {
                     break loop0;
                  }
               }
               _loc11_++;
            }
            _loc12_++;
         }
         return true;
      }

      private function handleRepair(param1:NetworkConnection, param2:ByteArray) : void
      {
         var _loc3_:RemotePlayerEntity = this.getConnectionPlayer(param1);
         if(_loc3_ == null || !_loc3_.alive)
         {
            return;
         }
         var _loc4_:int = param2.readInt();
         var _loc5_:int = param2.readInt();
         var _loc6_:int = param2.readInt();
         if(_loc4_ <= 0 || _loc6_ <= 0 || _loc4_ >= Item.ITEMS.length || _loc6_ >= Item.ITEMS.length)
         {
            return;
         }
         var _loc7_:Item = Item.ITEMS[_loc4_];
         var _loc8_:Item = Item.ITEMS[_loc6_];
         if(_loc7_ == null || _loc8_ == null || !_loc7_.destroyable)
         {
            return;
         }
         var _loc9_:Array = _loc7_.getMaterialItemForRepair();
         if(_loc9_ == null || _loc9_.indexOf(_loc8_) < 0)
         {
            return;
         }
         var _loc10_:ItemStack = this.findInventoryStack(_loc3_.inventory,_loc7_,_loc5_);
         if(_loc10_ == null || _loc10_.durability >= _loc7_.durability)
         {
            return;
         }
         var _loc11_:int = Item.getRepairPoints(_loc8_);
         if(_loc11_ <= 0)
         {
            return;
         }
         var _loc12_:int = Math.ceil((_loc7_.durability - _loc10_.durability) / _loc11_);
         var _loc13_:int = _loc3_.inventory.count(_loc8_);
         if(_loc13_ <= 0)
         {
            this.sendInventorySync(_loc3_.networkPlayerId);
            return;
         }
         if(_loc13_ > _loc12_)
         {
            _loc13_ = _loc12_;
         }
         _loc10_.durability = Math.min(_loc7_.durability,_loc10_.durability + _loc13_ * _loc11_);
         _loc3_.inventory.remove(_loc8_,_loc13_);
         this.sendInventorySync(_loc3_.networkPlayerId);
      }

      private function findInventoryStack(param1:CharacterInventory, param2:Item, param3:int) : ItemStack
      {
         var _loc4_:ItemStack = this.findStackInVector(param1.items,param2,param3);
         if(_loc4_ != null)
         {
            return _loc4_;
         }
         _loc4_ = this.findStackInVector(param1.armors,param2,param3);
         if(_loc4_ != null)
         {
            return _loc4_;
         }
         _loc4_ = this.findStackInVector(param1.socialArmors,param2,param3);
         if(_loc4_ != null)
         {
            return _loc4_;
         }
         return this.findStackInVector(param1.projectiles,param2,param3);
      }

      private function findStackInVector(param1:Vector.<ItemStack>, param2:Item, param3:int) : ItemStack
      {
         var _loc4_:ItemStack = null;
         for each(_loc4_ in param1)
         {
            if(_loc4_ != null && _loc4_.item == param2 && _loc4_.itemData == param3)
            {
               return _loc4_;
            }
         }
         return null;
      }

      private function updateRemoteRespawns(param1:int) : void
      {
         var _loc2_:RemotePlayerEntity = null;
         for each(_loc2_ in this._remotePlayers)
         {
            if(_loc2_.alive)
            {
               _loc2_.respawnTimer = 0;
            }
            else if(_loc2_.respawnTimer <= 0)
            {
               _loc2_.respawnTimer = PLAYER_RESPAWN_TIME;
            }
            else
            {
               _loc2_.respawnTimer -= param1;
               if(_loc2_.respawnTimer <= 0)
               {
                  this.placeAtGuestSpawn(_loc2_);
                  _loc2_.reset();
                  _loc2_.health = _loc2_.maxHealth * 0.5;
               }
            }
         }
      }

      private function sendWorldToPendingConnections() : void
      {
         if(this._server == null)
         {
            return;
         }
         var _loc1_:NetworkConnection = null;
         for each(_loc1_ in this._server.connections)
         {
            if(this._connectionIds[_loc1_] != null)
            {
               this.sendInitialState(_loc1_);
            }
         }
      }

      private function sendPing() : void
      {
         var _loc1_:ByteArray = new ByteArray();
         _loc1_.writeUnsignedInt(uint(new Date().time));
         if(this.isHost && this._server != null)
         {
            this._server.broadcast(MultiplayerProtocol.PING,HOST_PLAYER_ID,_loc1_);
         }
         else if(this.isClient && this._client != null)
         {
            this._client.send(MultiplayerProtocol.PING,this._localPlayerId,_loc1_);
         }
      }

      private function getLocalProfile() : Object
      {
         var _loc1_:Object = null;
         if(Context.game != null)
         {
            _loc1_ = new Object();
            Context.game.savePlayer(_loc1_);
         }
         else if(Context.cachedPlayerData != null)
         {
            _loc1_ = Context.cachedPlayerData;
         }
         else
         {
            _loc1_ = Context.startingPlayerData;
         }
         if(_loc1_ != null && Context.savedCustomize != null)
         {
            if(Context.savedCustomize.name != null && String(Context.savedCustomize.name).length > 0)
            {
               _loc1_.name = Context.savedCustomize.name;
            }
            if(Context.savedCustomize.gender != null)
            {
               _loc1_.gender = Context.savedCustomize.gender;
            }
            if(Context.savedCustomize.hair != null)
            {
               _loc1_.hair = Context.savedCustomize.hair;
            }
            if(Context.savedCustomize.head != null)
            {
               _loc1_.head = Context.savedCustomize.head;
            }
            if(Context.savedCustomize.hair_color != null)
            {
               _loc1_.hair_color = Context.savedCustomize.hair_color;
            }
         }
         return _loc1_;
      }

      private function getHostProfile() : Object
      {
         var _loc1_:Object = this.getLocalProfile();
         this._profiles[HOST_PLAYER_ID] = _loc1_;
         return _loc1_;
      }

      private function onClientDisconnected() : void
      {
         if(this._stopping)
         {
            return;
         }
         this.setStatus("DISCONNECTED");
         if(Context.game != null)
         {
            Context.app.quitGame();
         }
      }

      private function onNetworkError(param1:String) : void
      {
         this.setStatus("NETWORK ERROR: " + param1);
      }

      private function setStatus(param1:String) : void
      {
         if(Context.console != null)
         {
            Context.console.writeData("[MP] " + param1);
         }
         this.statusSignal.dispatch(param1);
      }
   }
}
