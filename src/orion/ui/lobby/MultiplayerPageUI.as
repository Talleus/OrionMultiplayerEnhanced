package orion.ui.lobby
{
   import assets.Images;
   import assets.Sounds;
   import flash.desktop.Clipboard;
   import flash.desktop.ClipboardFormats;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.DisplayObjectContainer;
   import flash.display.Graphics;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.filters.GlowFilter;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.net.SharedObject;
   import flash.system.System;
   import flash.text.AntiAliasType;
   import flash.text.TextField;
   import flash.text.TextFieldType;
   import flash.text.TextFormat;
   import flash.utils.ByteArray;
   import orion.ui.UIStyle;
   import orion.ui.base.ButtonUI;
   import orion.ui.base.LabelUI;
   import orion.ui.base.PanelUI;
   import orion.ui.base.TextBoxUI;
   import utils.Base64Decoder;
   import utils.Fonts;

   public final class MultiplayerPageUI extends PanelUI
   {

      private static var _compactBackground:BitmapData;

      private static var _connectBackground:BitmapData;

      private static var _chatBackground:BitmapData;

      private static var _hostBackground:BitmapData;

      private static var _hostBackgroundHeight:int;

      private static var _hostBackgroundShelfH:int;

      private static var _sendButtonImage:BitmapData;

      private static var _chatArrowRightImage:BitmapData;

      private static var _chatArrowLeftImage:BitmapData;

      private static var _createButtonImage:BitmapData;

      private static var _banButtonImage:BitmapData;

      private static var _kickButtonImage:BitmapData;

      private static var _arrowLeftImage:BitmapData;

      private static var _arrowRightImage:BitmapData;

      public static const STATE_MAIN:int = 0;

      public static const STATE_CONNECT_MENU:int = 1;

      public static const STATE_HOST_LOBBY:int = 2;

      public static const STATE_CLIENT_LOBBY:int = 3;

      private static const PW:int = 426;

      private static const PH:int = 315;

      private static const PH_HOST:int = 490;

      private static const COMPACT_HEIGHT:int = 112;

      private static const CONNECT_HEIGHT:int = 250;

      private static const CHAT_WIDTH:int = 250;

      private static const CHAT_HEIGHT:int = 315;

      private static var _LOC:Object = null;

      private static const CHAT_BUBBLE_B64:String = "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";

      private static const ARROW_LEFT_B64:String = CHAT_BUBBLE_B64;

      private static const ARROW_RIGHT_B64:String = CHAT_BUBBLE_B64;

      private static const BAN_BUTTON_B64:String = "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";

      private static const RED_BUTTON_B64:String = "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";

      private static var _friendsBackground:BitmapData = null;

      private var _panel:PanelUI;

      private var _caption:LabelUI;

      private var _inviteFriendButton:ButtonUI;

      private var _friendsModal:Sprite;

      private var _friendsPanel:Sprite;

      private var _friendsNote:LabelUI;

      private var _friendRows:Vector.<ButtonUI>;

      private var _friendNames:Vector.<LabelUI>;

      private var _friendIds:Array;

      private var _nameBoxFrame:Sprite;

      private var _closeFriendsButton:ButtonUI;

      private var _lastWorldClickTime:int = 0;

      private var _lastWorldClickTag:String = null;

      private var _cachedFriends:Array = [];

      private var _friendPage:int = 0;

      private var _prevFriendButton:ButtonUI;

      private var _nextFriendButton:ButtonUI;

      private var _friendPageLabel:LabelUI;

      private var _closeFriendsTopButton:ButtonUI;

      private var _status:LabelUI;

      private var _players:LabelUI;

      private var _localPlayerLabel:LabelUI;

      private var _ipLabel:LabelUI;

      private var _portLabel:LabelUI;

      private var _ipBox:TextBoxUI;

      private var _portBox:TextBoxUI;

      private var _ipValue:LabelUI;

      private var _copyLanNext:Boolean = false;

      private var _portValue:LabelUI;

      private var _hostButton:ButtonUI;

      private var _joinMenuButton:ButtonUI;

      private var _connectButton:ButtonUI;

      private var _connectCancelButton:ButtonUI;

      private var _connectCloseButton:ButtonUI;

      private var _startWorldButton:ButtonUI;

      private var _stopHostButton:ButtonUI;

      private var _disconnectButton:ButtonUI;

      private var _worldCaption:LabelUI;

      private var _worldNameBox:TextBoxUI;

      private var _createWorldButton:ButtonUI;

      private var _worldButtons:Vector.<ButtonUI>;

      private var _worldDetails:LabelUI;

      private var _rosterGroup:Sprite;

      private var _rosterSlotPanels:Vector.<Sprite>;

      private var _rosterSlotLabels:Vector.<LabelUI>;

      private var _rosterKickButtons:Vector.<ButtonUI>;

      private var _rosterBanButtons:Vector.<ButtonUI>;

      private var _blacklistButton:ButtonUI;

      private var _blacklistModal:Sprite;

      private var _blacklistPanel:Sprite;

      private var _closeBlacklistTopButton:ButtonUI;

      private var _closeBlacklistButton:ButtonUI;

      private var _blacklistPrevButton:ButtonUI;

      private var _blacklistNextButton:ButtonUI;

      private var _blacklistPageLabel:LabelUI;

      private var _blacklistEmptyLabel:LabelUI;

      private var _blacklistRows:Vector.<ButtonUI>;

      private var _blacklistNickLabels:Vector.<LabelUI>;

      private var _blacklistIpLabels:Vector.<LabelUI>;

      private var _blacklistRowEntries:Array;

      private var _blacklistPage:int = 0;

      private var _blacklistManualInput:TextField;

      private var _blacklistManualButton:ButtonUI;

      private var _clientSubtitle:LabelUI;

      private var _chatToggle:ButtonUI;

      private var _chatPanel:PanelUI;

      private var _chatText:TextField;

      private var _chatInput:TextField;

      private var _typingLabel:TextField;

      private var _chatInputBackground:Sprite;

      private var _sendButton:ButtonUI;

      private var _chatOpen:Boolean = false;

      private var _chatCaption:LabelUI;

      private var _state:int = 0;

      public function MultiplayerPageUI(param1:DisplayObjectContainer, param2:int = 0, param3:int = 0)
      {
         super(param1,param2,param3);
      }

      private static function initLoc() : void
      {
         if(_LOC != null)
         {
            return;
         }
         _LOC = {
            "title_multiplayer":{
               "en":"MULTIPLAYER",
               "ru":"СЕТЕВАЯ",
               "fr":"MULTIJOUEUR",
               "es":"MULTIJUGADOR",
               "vi":"NHIỀU NGƯỜI CHƠI",
               "ti":"ผู้เล่นหลายคน",
               "zh":"多人游戏"
            },
            "btn_host":{
               "en":"HOST",
               "ru":"ХОСТ",
               "fr":"HÉBERGEUR",
               "es":"ANFITRIÓN",
               "vi":"MÁY CHỦ",
               "ti":"โฮสต์",
               "zh":"创建房间"
            },
            "btn_connect":{
               "en":"CONNECT",
               "ru":"ПОДКЛЮЧИТЬСЯ",
               "fr":"REJOINDRE",
               "es":"CONECTAR",
               "vi":"KẾT NỐI",
               "ti":"เชื่อมต่อ",
               "zh":"连接游戏"
            },
            "lbl_ip":{
               "en":"IP:",
               "ru":"IP:",
               "fr":"IP :",
               "es":"IP:",
               "vi":"IP:",
               "ti":"IP:",
               "zh":"IP:"
            },
            "lbl_port":{
               "en":"PORT:",
               "ru":"ПОРТ:",
               "fr":"PORT :",
               "es":"PUERTO:",
               "vi":"CỔNG:",
               "ti":"พอร์ต:",
               "zh":"端口:"
            },
            "btn_cancel":{
               "en":"BACK",
               "ru":"НАЗАД",
               "fr":"ANNULER",
               "es":"CANCELAR",
               "vi":"HỦY",
               "ti":"ยกเลิก",
               "zh":"取消"
            },
            "btn_cancel_lobby":{
               "en":"BACK",
               "ru":"НАЗАД",
               "fr":"ANNULER",
               "es":"CANCELAR",
               "vi":"HỦY",
               "ti":"ยกเลิก",
               "zh":"取消"
            },
            "btn_start_world":{
               "en":"START WORLD",
               "ru":"СТАРТ МИРА",
               "fr":"LANCER LE MONDE",
               "es":"INICIAR MUNDO",
               "vi":"BẮT ĐẦU",
               "ti":"เริ่มโลก",
               "zh":"开始世界"
            },
            "btn_invite":{
               "en":"INVITE",
               "ru":"ПРИГЛАСИТЬ",
               "fr":"INVITER",
               "es":"INVITAR",
               "vi":"MỜI",
               "ti":"เชิญ",
               "zh":"邀请"
            },
            "btn_disconnect":{
               "en":"BACK",
               "ru":"НАЗАД",
               "fr":"DÉCONNEXION",
               "es":"DESCONECTAR",
               "vi":"NGẮT KẾT NỐI",
               "ti":"ตัดการเชื่อมต่อ",
               "zh":"断开连接"
            },
            "caption_worlds":{
               "en":"SELECT WORLD:",
               "ru":"ВЫБОР МИРА:",
               "fr":"CHOISIR LE MONDE :",
               "es":"ELEGIR MUNDO:",
               "vi":"CHỌN THẾ GIỚI:",
               "ti":"เลือกโลก:",
               "zh":"选择世界:"
            },
            "chat_caption":{
               "en":"CHAT",
               "ru":"ЧАТ",
               "fr":"TCHAT",
               "es":"CHAT",
               "vi":"TRÒ CHUYỆN",
               "ti":"แชท",
               "zh":"聊天"
            },
            "status_waiting":{
               "en":"WAITING FOR PLAYERS",
               "ru":"ОЖИДАНИЕ ИГРОКОВ",
               "fr":"EN ATTENTE DE JOUEURS",
               "es":"ESPERANDO JUGADORES",
               "vi":"CHỜ NGƯỜI CHƠI",
               "ti":"กำลังรอผู้เล่น",
               "zh":"等待玩家加入"
            },
            "connected_to_host":{
               "en":"CONNECTED TO HOST",
               "ru":"ПОДКЛЮЧЕНО К ХОСТУ",
               "fr":"CONNECTÉ À L\'HÔTE",
               "es":"CONECTADO AL ANFITRIÓN",
               "vi":"ĐÃ KẾT NỐI VỚI MÁY CHỦ",
               "ti":"เชื่อมต่อกับโฮสต์แล้ว",
               "zh":"已连接到房主"
            },
            "waiting_host_start":{
               "en":"WAITING FOR HOST TO START GAME...",
               "ru":"ОЖИДАНИЕ ЗАПУСКА ИГРЫ ХОСТОМ...",
               "fr":"EN ATTENTE DU LANCEMENT PAR L\'HÔTE...",
               "es":"ESPERANDO QUE EL ANFITRIÓN INICIE...",
               "vi":"CHỜ CHỦ PHÒNG BẮT ĐẦU TRÒ CHƠI...",
               "ti":"กำลังรอโฮสต์เริ่มเกม...",
               "zh":"等待房主开始游戏..."
            },
            "players_count":{
               "en":"PLAYERS: ",
               "ru":"ИГРОКОВ: ",
               "fr":"JOUEURS : ",
               "es":"JUGADORES: ",
               "vi":"NGƯỜI CHƠI: ",
               "ti":"ผู้เล่น: ",
               "zh":"玩家数: "
            },
            "host_port_players":{
               "en":"PORT: 27015   •   PLAYERS: ",
               "ru":"ПОРТ: 27015   •   ИГРОКОВ: ",
               "fr":"PORT : 27015   •   JOUEURS : ",
               "es":"PUERTO: 27015   •   JUGADORES: ",
               "vi":"CỔNG: 27015   •   NGƯỜI CHƠI: ",
               "ti":"พอร์ต: 27015   •   ผู้เล่น: ",
               "zh":"端口: 27015   •   玩家数: "
            },
            "roster_empty":{
               "en":"(Empty)",
               "ru":"(Свободно)",
               "fr":"(Libre)",
               "es":"(Libre)",
               "vi":"(Trống)",
               "ti":"(ว่าง)",
               "zh":"(空闲)"
            },
            "roster_host_you":{
               "en":" (HOST / YOU)",
               "ru":" (ХОСТ / ВЫ)",
               "fr":" (HÔTE / VOUS)",
               "es":" (ANFITRIÓN / TÚ)",
               "vi":" (CHỦ PHÒNG / BẠN)",
               "ti":" (โฮสต์ / คุณ)",
               "zh":" (房主 / 你)"
            },
            "roster_host":{
               "en":" (HOST)",
               "ru":" (ХОСТ)",
               "fr":" (HÔTE)",
               "es":" (ANFITRIÓN)",
               "vi":" (CHỦ PHÒNG)",
               "ti":" (โฮสต์)",
               "zh":" (房主)"
            },
            "roster_you":{
               "en":" (YOU)",
               "ru":" (ВЫ)",
               "fr":" (VOUS)",
               "es":" (TÚ)",
               "vi":" (BẠN)",
               "ti":" (คุณ)",
               "zh":" (你)"
            },
            "btn_kick":{
               "en":"KICK",
               "ru":"КИК",
               "fr":"EXPULSER",
               "es":"EXPULSAR",
               "vi":"ĐÁ",
               "ti":"เตะ",
               "zh":"踢出"
            },
            "btn_ban":{
               "en":"BAN",
               "ru":"БАН",
               "fr":"BANNIR",
               "es":"BANEAR",
               "vi":"CẤM",
               "ti":"แบน",
               "zh":"封禁"
            },
            "friends_title":{
               "en":"INVITE FRIENDS (STEAM)",
               "ru":"ПРИГЛАСИТЬ ДРУЗЕЙ (STEAM)",
               "fr":"INVITER DES AMIS (STEAM)",
               "es":"INVITAR AMIGOS (STEAM)",
               "vi":"MỜI BẠN BÈ (STEAM)",
               "ti":"เชิญเพื่อน (STEAM)",
               "zh":"邀请好友 (STEAM)"
            },
            "friends_btn_invite":{
               "en":"INVITE",
               "ru":"ПОЗВАТЬ",
               "fr":"INVITER",
               "es":"INVITAR",
               "vi":"MỜI",
               "ti":"เชิญ",
               "zh":"邀请"
            },
            "friends_btn_close":{
               "en":"CLOSE",
               "ru":"ЗАКРЫТЬ",
               "fr":"FERMER",
               "es":"CERRAR",
               "vi":"ĐÓNG",
               "ti":"ปิด",
               "zh":"关闭"
            },
            "friends_no_friends":{
               "en":"- no steam friends -",
               "ru":"- нет друзей в Steam -",
               "fr":"- aucun ami Steam -",
               "es":"- sin amigos de Steam -",
               "vi":"- không có bạn Steam -",
               "ti":"- ไม่มีเพื่อนใน Steam -",
               "zh":"- 没有 Steam 好友 -"
            },
            "friends_note_normal":{
               "en":"INVITE = COPIES IP AND OPENS STEAM CHAT",
               "ru":"ПОЗВАТЬ = СКОПИРУЕТ IP И ОТКРОЕТ ЧАТ STEAM",
               "fr":"INVITER = COPIE L\'IP ET OUVRE LE CHAT STEAM",
               "es":"INVITAR = COPIA IP Y ABRE CHAT DE STEAM",
               "vi":"MỜI = SAO CHÉP IP VÀ MỞ CHAT STEAM",
               "ti":"เชิญ = คัดลอก IP และเปิดแชท STEAM",
               "zh":"邀请 = 复制 IP 并打开 Steam 聊天"
            },
            "friends_note_none":{
               "en":"NO STEAM FRIENDS FOUND - PLAY BY IP",
               "ru":"STEAM ДРУЗЬЯ НЕ НАЙДЕНЫ - ИГРАЙТЕ ПО IP",
               "fr":"AUCUN AMI TROUVÉ - JOUEZ PAR IP",
               "es":"AMIGOS NO ENCONTRADOS - JUEGA POR IP",
               "vi":"KHÔNG CÓ BẠN STEAM - HÃY CHƠI QUA IP",
               "ti":"ไม่พบเพื่อนใน STEAM - เล่นผ่าน IP",
               "zh":"未找到 STEAM 好友 - 请通过 IP 联机"
            },
            "friends_copied_ip":{
               "en":"COPIED IP: ",
               "ru":"СКОПИРОВАН IP: ",
               "fr":"IP COPIÉE : ",
               "es":"IP COPIADA: ",
               "vi":"ĐÃ SAO CHÉP IP: ",
               "ti":"คัดลอก IP แล้ว: ",
               "zh":"已复制 IP: "
            },
            "blacklist_title":{
               "en":"BLACKLIST",
               "ru":"ЧЕРНЫЙ СПИСОК",
               "fr":"LISTE NOIRE",
               "es":"LISTA NEGRA",
               "vi":"DANH SÁCH ĐEN",
               "ti":"บัญชีดำ",
               "zh":"黑名单"
            },
            "blacklist_empty":{
               "en":"(Blacklist is empty)",
               "ru":"(Список блокировок пуст)",
               "fr":"(La liste noire est vide)",
               "es":"(La lista negra está vacía)",
               "vi":"(Danh sách đen trống)",
               "ti":"(บัญชีดำว่างเปล่า)",
               "zh":"(黑名单为空)"
            },
            "blacklist_unban":{
               "en":"UNBAN",
               "ru":"РАЗБАНИТЬ",
               "fr":"DÉBANNIR",
               "es":"DESBANEAR",
               "vi":"HỦY CẤM",
               "ti":"ปลดแบน",
               "zh":"解封"
            },
            "blacklist_manual_title":{
               "en":"Add to ban (Nick or IP):",
               "ru":"Добавить в бан (Ник или IP):",
               "fr":"Bannir (Pseudo ou IP) :",
               "es":"Añadir a lista negra (Nick o IP):",
               "vi":"Thêm vào cấm (Tên hoặc IP):",
               "ti":"เพิ่มเข้าบัญชีดำ (ชื่อหรือ IP):",
               "zh":"添加封禁 (昵称或 IP):"
            },
            "blacklist_note":{
               "en":"Banned players cannot connect to your lobby",
               "ru":"Заблокированные игроки не смогут подключиться к вам",
               "fr":"Les joueurs bannis ne peuvent pas vous rejoindre",
               "es":"Los jugadores bloqueados no podrán unirse",
               "vi":"Người chơi bị cấm không thể kết nối tới phòng",
               "ti":"ผู้เล่นที่ถูกแบนจะไม่สามารถเชื่อมต่อกับคุณได้",
               "zh":"被封禁的玩家无法连接到你的房间"
            },
            "blacklist_no_nick":{
               "en":"[No Nick]",
               "ru":"[Без ника]",
               "fr":"[Sans pseudo]",
               "es":"[Sin nick]",
               "vi":"[Không tên]",
               "ti":"[ไม่มีชื่อ]",
               "zh":"[无昵称]"
            },
            "created":{
               "en":"CREATED: ",
               "ru":"СОЗДАН: ",
               "fr":"CRÉÉ : ",
               "es":"CREADO: ",
               "vi":"TẠO: ",
               "ti":"สร้าง: ",
               "zh":"创建: "
            },
            "modified":{
               "en":"MODIFIED: ",
               "ru":"ИЗМЕНЁН: ",
               "fr":"MODIFIÉ : ",
               "es":"MODIFICADO: ",
               "vi":"SỬA: ",
               "ti":"แก้ไข: ",
               "zh":"修改: "
            },
            "last_played":{
               "en":"LAST PLAYED: ",
               "ru":"ПОСЛЕДНИЙ ВХОД: ",
               "fr":"DERNIÈRE PARTIE : ",
               "es":"ÚLTIMA PARTIDA: ",
               "vi":"CHƠI GẦN NHẤT: ",
               "ti":"เล่นล่าสุด: ",
               "zh":"最近游玩: "
            }
         };
      }

      public static function loc(key:String) : String
      {
         initLoc();
         var lang:String = "en";
         if(Context.app != null && Context.app._choosedLanguage != null)
         {
            lang = Context.app._choosedLanguage;
         }
         var row:Object = _LOC[key];
         if(row != null)
         {
            if(row[lang] != undefined && row[lang] != null)
            {
               return String(row[lang]);
            }
            if(row["en"] != undefined && row["en"] != null)
            {
               return String(row["en"]);
            }
         }
         return key;
      }

      private static function getCompactBackground() : BitmapData
      {
         return getHostBackground(118,0);
      }

      private static function getChatBackground() : BitmapData
      {
         if(_chatBackground == null)
         {
            _chatBackground = new BitmapData(CHAT_WIDTH,CHAT_HEIGHT,true,0);
            _chatBackground.copyPixels(Images.PANEL_ERROR_BACKGROUND,new Rectangle(0,0,125,CHAT_HEIGHT),new Point(0,0));
            _chatBackground.copyPixels(Images.PANEL_ERROR_BACKGROUND,new Rectangle(301,0,125,CHAT_HEIGHT),new Point(125,0));
         }
         return _chatBackground;
      }

      private static function getHostBackground(param1:int, param2:int = 0) : BitmapData
      {
         if(param2 <= 0)
         {
            if(param1 >= 400)
            {
               param2 = 128;
            }
            else if(param1 >= 300)
            {
               param2 = 78;
            }
            else if(param1 >= 200)
            {
               param2 = 34;
            }
         }
         if(_hostBackground == null || _hostBackgroundHeight != param1 || _hostBackgroundShelfH != param2)
         {
            _hostBackgroundHeight = param1;
            _hostBackgroundShelfH = param2;
            var src:BitmapData = Images.PANEL_ERROR_BACKGROUND;
            _hostBackground = new BitmapData(PW,param1,true,0);
            var capTop:int = 34;
            var capBot:int = 12;
            var shelfH:int = param2;
            if(shelfH > param1 - capTop - capBot)
            {
               shelfH = param1 - capTop - capBot;
            }
            var shelfY:int = param1 - shelfH;
            var bodyH:int = shelfY - capTop;
            var darkBodySrcH:int = 240 - capTop;
            _hostBackground.copyPixels(src,new Rectangle(0,0,PW,capTop),new Point(0,0));
            if(bodyH > 0)
            {
               var mBody:Matrix = new Matrix();
               mBody.scale(1,bodyH / darkBodySrcH);
               mBody.translate(0,capTop);
               var bmpBody:BitmapData = new BitmapData(PW,darkBodySrcH,true,0);
               bmpBody.copyPixels(src,new Rectangle(0,capTop,PW,darkBodySrcH),new Point(0,0));
               _hostBackground.draw(bmpBody,mBody,null,null,new Rectangle(0,capTop,PW,bodyH),true);
               bmpBody.dispose();
            }
            if(shelfH > capBot)
            {
               _hostBackground.copyPixels(src,new Rectangle(0,254,PW,3),new Point(0,shelfY));
               var shelfFillH:int = shelfH - 3 - capBot;
               if(shelfFillH > 0)
               {
                  var mShelf:Matrix = new Matrix();
                  mShelf.scale(1,shelfFillH / 30);
                  mShelf.translate(0,shelfY + 3);
                  var bmpShelf:BitmapData = new BitmapData(PW,30,true,0);
                  bmpShelf.copyPixels(src,new Rectangle(0,260,PW,30),new Point(0,0));
                  _hostBackground.draw(bmpShelf,mShelf,null,null,new Rectangle(0,shelfY + 3,PW,shelfFillH),true);
                  bmpShelf.dispose();
               }
            }
            _hostBackground.copyPixels(src,new Rectangle(0,src.height - capBot,PW,capBot),new Point(0,param1 - capBot));
         }
         return _hostBackground;
      }

      private static function getFriendsBackground() : BitmapData
      {
         if(_friendsBackground == null)
         {
            var targetW:int = PW;
            var targetH:int = 455;
            var shelfH:int = 74;
            var src:BitmapData = Images.PANEL_ERROR_BACKGROUND;
            _friendsBackground = new BitmapData(targetW,targetH,true,0);
            var capTop:int = 34;
            var capBot:int = 12;
            var shelfY:int = targetH - shelfH;
            var bodyH:int = shelfY - capTop;
            var darkBodySrcH:int = 240 - capTop;
            _friendsBackground.copyPixels(src,new Rectangle(0,0,targetW,capTop),new Point(0,0));
            if(bodyH > 0)
            {
               var mBody:Matrix = new Matrix();
               mBody.scale(1,bodyH / darkBodySrcH);
               mBody.translate(0,capTop);
               var bmpBody:BitmapData = new BitmapData(targetW,darkBodySrcH,true,0);
               bmpBody.copyPixels(src,new Rectangle(0,capTop,targetW,darkBodySrcH),new Point(0,0));
               _friendsBackground.draw(bmpBody,mBody,null,null,new Rectangle(0,capTop,targetW,bodyH),true);
               bmpBody.dispose();
            }
            _friendsBackground.copyPixels(src,new Rectangle(0,254,targetW,3),new Point(0,shelfY));
            var shelfFillH:int = shelfH - 3 - capBot;
            if(shelfFillH > 0)
            {
               var mShelf:Matrix = new Matrix();
               mShelf.scale(1,shelfFillH / 30);
               mShelf.translate(0,shelfY + 3);
               var bmpShelf:BitmapData = new BitmapData(targetW,30,true,0);
               bmpShelf.copyPixels(src,new Rectangle(0,260,targetW,30),new Point(0,0));
               _friendsBackground.draw(bmpShelf,mShelf,null,null,new Rectangle(0,shelfY + 3,targetW,shelfFillH),true);
               bmpShelf.dispose();
            }
            _friendsBackground.copyPixels(src,new Rectangle(0,src.height - capBot,targetW,capBot),new Point(0,targetH - capBot));
         }
         return _friendsBackground;
      }

      private static function getConnectBackground(targetW:int = 290, targetH:int = 200) : BitmapData
      {
         if(_connectBackground == null || _connectBackground.width != targetW || _connectBackground.height != targetH)
         {
            var src:BitmapData = Images.PANEL_ERROR_BACKGROUND;
            _connectBackground = new BitmapData(targetW,targetH,true,0);
            var capX:int = 16;
            var capTop:int = 34;
            var capBot:int = 10;
            var midW:int = targetW - capX * 2;
            var srcMidW:int = src.width - capX * 2;
            var bodyH:int = targetH - capTop - capBot;
            var srcBodyH:int = src.height - capTop - capBot;
            _connectBackground.copyPixels(src,new Rectangle(0,0,capX,capTop),new Point(0,0));
            _connectBackground.copyPixels(src,new Rectangle(src.width - capX,0,capX,capTop),new Point(targetW - capX,0));
            var mTop:Matrix = new Matrix();
            mTop.scale(midW / srcMidW,1);
            mTop.translate(capX,0);
            var bmpTop:BitmapData = new BitmapData(srcMidW,capTop,true,0);
            bmpTop.copyPixels(src,new Rectangle(capX,0,srcMidW,capTop),new Point(0,0));
            _connectBackground.draw(bmpTop,mTop,null,null,new Rectangle(capX,0,midW,capTop),true);
            bmpTop.dispose();
            _connectBackground.copyPixels(src,new Rectangle(0,src.height - capBot,capX,capBot),new Point(0,targetH - capBot));
            _connectBackground.copyPixels(src,new Rectangle(src.width - capX,src.height - capBot,capX,capBot),new Point(targetW - capX,targetH - capBot));
            var mBot:Matrix = new Matrix();
            mBot.scale(midW / srcMidW,1);
            mBot.translate(capX,targetH - capBot);
            var bmpBot:BitmapData = new BitmapData(srcMidW,capBot,true,0);
            bmpBot.copyPixels(src,new Rectangle(capX,src.height - capBot,srcMidW,capBot),new Point(0,0));
            _connectBackground.draw(bmpBot,mBot,null,null,new Rectangle(capX,targetH - capBot,midW,capBot),true);
            bmpBot.dispose();
            var mBodyL:Matrix = new Matrix();
            mBodyL.scale(1,bodyH / srcBodyH);
            mBodyL.translate(0,capTop);
            var bmpBodyL:BitmapData = new BitmapData(capX,srcBodyH,true,0);
            bmpBodyL.copyPixels(src,new Rectangle(0,capTop,capX,srcBodyH),new Point(0,0));
            _connectBackground.draw(bmpBodyL,mBodyL,null,null,new Rectangle(0,capTop,capX,bodyH),true);
            bmpBodyL.dispose();
            var mBodyR:Matrix = new Matrix();
            mBodyR.scale(1,bodyH / srcBodyH);
            mBodyR.translate(targetW - capX,capTop);
            var bmpBodyR:BitmapData = new BitmapData(capX,srcBodyH,true,0);
            bmpBodyR.copyPixels(src,new Rectangle(src.width - capX,capTop,capX,srcBodyH),new Point(0,0));
            _connectBackground.draw(bmpBodyR,mBodyR,null,null,new Rectangle(targetW - capX,capTop,capX,bodyH),true);
            bmpBodyR.dispose();
            var mBodyM:Matrix = new Matrix();
            mBodyM.scale(midW / srcMidW,bodyH / srcBodyH);
            mBodyM.translate(capX,capTop);
            var bmpBodyM:BitmapData = new BitmapData(srcMidW,srcBodyH,true,0);
            bmpBodyM.copyPixels(src,new Rectangle(capX,capTop,srcMidW,srcBodyH),new Point(0,0));
            _connectBackground.draw(bmpBodyM,mBodyM,null,null,new Rectangle(capX,capTop,midW,bodyH),true);
            bmpBodyM.dispose();
         }
         return _connectBackground;
      }

      private static function getSendButtonImage() : BitmapData
      {
         if(_sendButtonImage == null)
         {
            _sendButtonImage = new BitmapData(30,115,true,0);
            var colors:Array = [494243,899028,354171,4413276];
            var i:int = 0;
            while(i < 4)
            {
               var icon:Sprite = new Sprite();
               icon.graphics.lineStyle(1,4775412,1,true);
               icon.graphics.beginFill(uint(colors[i]),1);
               icon.graphics.drawRoundRect(0,0,30,28,7,7);
               icon.graphics.endFill();
               icon.graphics.lineStyle(1,480106,1,true);
               icon.graphics.beginFill(16777215,i == 3 ? 0.45 : 1);
               icon.graphics.moveTo(6,13);
               icon.graphics.lineTo(24,6);
               icon.graphics.lineTo(18,23);
               icon.graphics.lineTo(13,16);
               icon.graphics.lineTo(9,20);
               icon.graphics.lineTo(10,15);
               icon.graphics.lineTo(6,13);
               icon.graphics.endFill();
               icon.graphics.moveTo(10,15);
               icon.graphics.lineTo(20,10);
               var matrix:Matrix = new Matrix();
               matrix.translate(0,i * 29);
               _sendButtonImage.draw(icon,matrix,null,null,null,true);
               i++;
            }
         }
         return _sendButtonImage;
      }

      private static function getBanButtonImage() : BitmapData
      {
         var dec:Base64Decoder;
         var bytes:ByteArray;
         if(_banButtonImage == null)
         {
            try
            {
               dec = new Base64Decoder();
               dec.decode(BAN_BUTTON_B64);
               bytes = dec.drain();
               bytes.uncompress();
               _banButtonImage = new BitmapData(25,77,true,0);
               _banButtonImage.setPixels(new Rectangle(0,0,25,77),bytes);
            }
            catch(err:Error)
            {
               _banButtonImage = Images.BUTTON_GAME_SMALL_LANGUAGE;
            }
         }
         return _banButtonImage;
      }

      private static function getChatArrowImage(left:Boolean) : BitmapData
      {
         var dec:Base64Decoder;
         var bytes:ByteArray;
         var target:BitmapData = left ? _arrowLeftImage : _arrowRightImage;
         if(target == null)
         {
            try
            {
               dec = new Base64Decoder();
               dec.decode(left ? ARROW_LEFT_B64 : ARROW_RIGHT_B64);
               bytes = dec.drain();
               bytes.uncompress();
               target = new BitmapData(25,77,true,0);
               target.setPixels(new Rectangle(0,0,25,77),bytes);
            }
            catch(err:Error)
            {
               target = Images.BUTTON_GAME_SMALL_LANGUAGE;
            }
            if(left)
            {
               _arrowLeftImage = target;
            }
            else
            {
               _arrowRightImage = target;
            }
         }
         return target;
      }

      private static function getCreateButtonImage() : BitmapData
      {
         if(_createButtonImage == null)
         {
            _createButtonImage = createSlicedButton(Images.BUTTON_SET_AVATAR,110,36);
         }
         return _createButtonImage;
      }

      private static function createSlicedButton(src:BitmapData, targetW:int, targetH:int) : BitmapData
      {
         var resH:int = targetH * 4 + 3;
         var res:BitmapData = new BitmapData(targetW,resH,true,0);
         var capW:int = 14;
         if(capW > targetW / 2)
         {
            capW = int(targetW / 2);
         }
         var srcFrameH:int = int((src.height - 3) / 4);
         if(srcFrameH < 1)
         {
            srcFrameH = 49;
         }
         var srcStride:int = srcFrameH + 1;
         var k:int = 0;
         while(k < 4)
         {
            var srcY:int = k * srcStride;
            var dstY:int = k * (targetH + 1);
            var mLeft:Matrix = new Matrix();
            mLeft.scale(1,targetH / srcFrameH);
            mLeft.translate(0,dstY);
            var leftBmp:BitmapData = new BitmapData(capW,srcFrameH,true,0);
            leftBmp.copyPixels(src,new Rectangle(0,srcY,capW,srcFrameH),new Point(0,0));
            res.draw(leftBmp,mLeft,null,null,new Rectangle(0,dstY,capW,targetH),true);
            leftBmp.dispose();
            var mRight:Matrix = new Matrix();
            mRight.scale(1,targetH / srcFrameH);
            mRight.translate(targetW - capW,dstY);
            var rightBmp:BitmapData = new BitmapData(capW,srcFrameH,true,0);
            rightBmp.copyPixels(src,new Rectangle(src.width - capW,srcY,capW,srcFrameH),new Point(0,0));
            res.draw(rightBmp,mRight,null,null,new Rectangle(targetW - capW,dstY,capW,targetH),true);
            rightBmp.dispose();
            var midW:int = targetW - capW * 2;
            var srcMidW:int = src.width - capW * 2;
            if(midW > 0 && srcMidW > 0)
            {
               var mMid:Matrix = new Matrix();
               mMid.scale(midW / srcMidW,targetH / srcFrameH);
               mMid.translate(capW,dstY);
               var midBmp:BitmapData = new BitmapData(srcMidW,srcFrameH,true,0);
               midBmp.copyPixels(src,new Rectangle(capW,srcY,srcMidW,srcFrameH),new Point(0,0));
               res.draw(midBmp,mMid,null,null,new Rectangle(capW,dstY,midW,targetH),true);
               midBmp.dispose();
            }
            k++;
         }
         return res;
      }

      private static function getKickButtonImage() : BitmapData
      {
         var dec:Base64Decoder;
         var bytes:ByteArray;
         if(_kickButtonImage == null)
         {
            try
            {
               dec = new Base64Decoder();
               dec.decode(RED_BUTTON_B64);
               bytes = dec.drain();
               bytes.uncompress();
               _kickButtonImage = new BitmapData(54,95,true,0);
               _kickButtonImage.setPixels(new Rectangle(0,0,54,95),bytes);
            }
            catch(err:Error)
            {
               if(Images.BUTTON_GAME_INVENTORY_RED_BIG != null)
               {
                  _kickButtonImage = createSlicedButton(Images.BUTTON_GAME_INVENTORY_RED_BIG,54,23);
               }
            }
         }
         return _kickButtonImage;
      }

      override protected function init() : void
      {
         super.init();
         this.showMain();
         if(Context.multiplayer != null)
         {
            Context.multiplayer.statusSignal.add(this.onStatus);
            Context.multiplayer.playersChangedSignal.add(this.onPlayersChanged);
         }
      }

      override protected function addChildren() : void
      {
         super.addChildren();
         if(this.stage != null)
         {
            setSize(this.stage.stageWidth,this.stage.stageHeight);
         }
         this._panel = new PanelUI(this).setImage(Images.PANEL_ERROR_BACKGROUND) as PanelUI;
         this._panel.setSize(PW,PH);
         this._caption = new LabelUI(this._panel,0,6).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setVerticalAlign(LabelUI.MIDDLE_ALIGN).setFont(Fonts.ZANTROKE,22,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).addFilter(UIStyle.BLACK_SHADOW_FILTER).setSize(PW,26) as LabelUI;
         this._status = new LabelUI(this._panel,0,36).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setSystemFont("Verdana",14,16769439).setSize(PW,20) as LabelUI;
         this._ipValue = new LabelUI(this._panel,0,56).setSystemFont("Verdana",11,16777215).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setSize(PW,18) as LabelUI;
         this._ipValue.buttonMode = true;
         this._ipValue.useHandCursor = true;
         this._players = new LabelUI(this._panel,0,74).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setSystemFont("Verdana",13,16777215).setSize(PW,18) as LabelUI;
         this._localPlayerLabel = new LabelUI(this._panel,0,92).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setSystemFont("Verdana",14,14745578).setSize(PW,20) as LabelUI;
         this._ipLabel = new LabelUI(this._panel,28,52).setText("IP:").setSystemFont("Verdana",14,16777215) as LabelUI;
         this._portLabel = new LabelUI(this._panel,28,96).setText("PORT:").setSystemFont("Verdana",14,16777215) as LabelUI;
         this._ipBox = new TextBoxUI(this._panel,76,48).setMaxLength(45).setSize(320,32) as TextBoxUI;
         this._ipBox.textField.embedFonts = false;
         this._ipBox.textField.textColor = 16777215;
         var ipFmt:TextFormat = new TextFormat("Verdana",14,16777215);
         this._ipBox.textField.defaultTextFormat = ipFmt;
         this._ipBox.textField.setTextFormat(ipFmt);
         this._portBox = new TextBoxUI(this._panel,76,92).setMaxLength(5).setOnlyDigits(true).setSize(110,32) as TextBoxUI;
         this._portBox.textField.embedFonts = false;
         this._portBox.textField.textColor = 16777215;
         var portFmt:TextFormat = new TextFormat("Verdana",14,16777215);
         this._portBox.textField.defaultTextFormat = portFmt;
         this._portBox.textField.setTextFormat(portFmt);
         this._hostButton = this.makeButton(15,47);
         this._joinMenuButton = this.makeButton(221,47);
         this._connectButton = this.makeButton(18,168);
         this._connectButton.setSize(190,49);
         this._connectCancelButton = this.makeButton(218,168);
         this._connectCancelButton.setSize(190,49);
         this._connectCancelButton.setText(Context.app._choosedLanguage == "ru" ? "НАЗАД" : "BACK");
         this._connectCancelButton.visible = false;
         this._connectCloseButton = new ButtonUI(this._panel,262,4).setImage(Images.BUTTON_GAME_INVENTORY_EXIT).setSize(25,25) as ButtonUI;
         this._connectCloseButton.visible = false;
         this._startWorldButton = this.makeButton(18,260);
         this._startWorldButton.setSize(190,49);
         this._inviteFriendButton = new ButtonUI(this._panel,218,260).setText(Context.app._choosedLanguage == "ru" ? "ПРИГЛАСИТЬ" : "INVITE").setTextFont(Fonts.ZANTROKE,15,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(Images.BUTTON_SET_AVATAR).setMargin(0,2).setSize(190,49) as ButtonUI;
         this._inviteFriendButton.visible = false;
         this._stopHostButton = this.makeButton(118,314);
         this._stopHostButton.setSize(190,49);
         this._disconnectButton = this.makeButton(118,260);
         this._disconnectButton.setSize(190,49);
         this._worldCaption = new LabelUI(this._panel,0,118).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setFont(Fonts.ZANTROKE,18,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(PW,22) as LabelUI;
         this._nameBoxFrame = new Sprite();
         this._panel.addChild(this._nameBoxFrame);
         this._worldNameBox = new TextBoxUI(this._panel,24,146).setMaxLength(24).setSize(260,36) as TextBoxUI;
         this._worldNameBox.textField.embedFonts = false;
         this._worldNameBox.textField.textColor = 16777215;
         var worldFmt:TextFormat = new TextFormat("Verdana",16,16777215);
         this._worldNameBox.textField.defaultTextFormat = worldFmt;
         this._worldNameBox.textField.setTextFormat(worldFmt);
         this._createWorldButton = new ButtonUI(this._panel,292,146).setTextFont(Fonts.ZANTROKE,14,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(getCreateButtonImage()).setMargin(0,2).setSize(110,36) as ButtonUI;
         this._clientSubtitle = new LabelUI(this._panel,0,52).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setFont(Fonts.ZANTROKE,12,16766240).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(PW,18) as LabelUI;
         this._clientSubtitle.visible = false;
         this._rosterGroup = new Sprite();
         this._panel.addChild(this._rosterGroup);
         this._rosterSlotPanels = new Vector.<Sprite>(4,true);
         this._rosterSlotLabels = new Vector.<LabelUI>(4,true);
         this._rosterKickButtons = new Vector.<ButtonUI>(4,true);
         this._rosterBanButtons = new Vector.<ButtonUI>(4,true);
         var rIdx:int = 0;
         while(rIdx < 4)
         {
            var rSlot:Sprite = new Sprite();
            rSlot.x = 20;
            rSlot.y = 90 + rIdx * 27;
            var rG:Graphics = rSlot.graphics;
            rG.lineStyle(1,1724254,0.85,true);
            rG.beginFill(665134,0.85);
            rG.drawRoundRect(0,0,386,25,5,5);
            rG.endFill();
            this._rosterGroup.addChild(rSlot);
            this._rosterSlotPanels[rIdx] = rSlot;
            var rLbl:LabelUI = new LabelUI(rSlot,12,3).setAutoSize(false).setFont(Fonts.ZANTROKE,13,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(252,20) as LabelUI;
            this._rosterSlotLabels[rIdx] = rLbl;
            if(rIdx > 0)
            {
               var rKick:ButtonUI = new ButtonUI(rSlot,268,1).setTextFont(Fonts.ZANTROKE,11,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(getKickButtonImage()).setMargin(0,1).setSize(54,23) as ButtonUI;
               rKick.text = Context.app._choosedLanguage == "ru" ? "КИК" : "KICK";
               rKick.addEventListener(MouseEvent.CLICK,this.onRosterKickClick);
               rKick.visible = false;
               this._rosterKickButtons[rIdx] = rKick;
               var rBan:ButtonUI = new ButtonUI(rSlot,326,1).setTextFont(Fonts.ZANTROKE,11,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(getKickButtonImage()).setMargin(0,1).setSize(54,23) as ButtonUI;
               rBan.text = Context.app._choosedLanguage == "ru" ? "БАН" : "BAN";
               rBan.addEventListener(MouseEvent.CLICK,this.onRosterBanClick);
               rBan.visible = false;
               this._rosterBanButtons[rIdx] = rBan;
            }
            rIdx++;
         }
         this._worldButtons = new Vector.<ButtonUI>(5,true);
         var worldIndex:int = 0;
         while(worldIndex < this._worldButtons.length)
         {
            this._worldButtons[worldIndex] = new ButtonUI(this._panel,43,224 + worldIndex * 42).setTextFont(Fonts.ZANTROKE,14,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,340,38)).setMargin(0,2).setSize(340,38) as ButtonUI;
            worldIndex++;
         }
         this._worldDetails = new LabelUI(this._panel,10,350).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setSystemFont("Verdana",11,16769439).setSize(PW - 20,32) as LabelUI;
         this._blacklistButton = new ButtonUI(this._panel,PW - 58,32).setImage(getBanButtonImage()).setSize(25,25) as ButtonUI;
         this._chatToggle = new ButtonUI(this._panel,PW - 29,32).setImage(getChatArrowImage(false)).setSize(25,25) as ButtonUI;
         this._chatPanel = new PanelUI(this).setImage(getChatBackground()) as PanelUI;
         this._chatPanel.setSize(CHAT_WIDTH,CHAT_HEIGHT);
         this._chatPanel.visible = false;
         this._chatText = new TextField();
         this._chatText.x = 12;
         this._chatText.y = 42;
         this._chatText.width = 226;
         this._chatText.height = 205;
         this._chatText.multiline = true;
         this._chatText.wordWrap = true;
         this._chatText.selectable = false;
         this._chatText.embedFonts = false;
         this._chatText.antiAliasType = AntiAliasType.ADVANCED;
         var fmt:TextFormat = new TextFormat("Segoe UI Emoji",14,16777215);
         this._chatText.defaultTextFormat = fmt;
         this._chatPanel.addChild(this._chatText);
         this._chatCaption = new LabelUI(this._chatPanel,0,4).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setFont(Fonts.ZANTROKE,24,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).addFilter(UIStyle.BLACK_SHADOW_FILTER).setSize(CHAT_WIDTH,32) as LabelUI;
         this._chatInputBackground = new Sprite();
         this._chatInputBackground.x = 10;
         this._chatInputBackground.y = 273;
         this._chatInputBackground.graphics.beginFill(1054752,0.95);
         this._chatInputBackground.graphics.lineStyle(2,1802908,1,true);
         this._chatInputBackground.graphics.drawRoundRect(0,0,194,28,8,8);
         this._chatInputBackground.graphics.endFill();
         this._chatInputBackground.graphics.lineStyle(1,2470358,1,true);
         this._chatInputBackground.graphics.drawRoundRect(1,1,192,26,6,6);
         this._chatPanel.addChild(this._chatInputBackground);
         this._chatInput = new TextField();
         this._chatInput.x = 14;
         this._chatInput.y = 276;
         this._chatInput.width = 186;
         this._chatInput.height = 22;
         this._chatInput.type = TextFieldType.INPUT;
         this._chatInput.selectable = true;
         this._chatInput.mouseEnabled = true;
         this._chatInput.tabEnabled = true;
         this._chatInput.maxChars = 100;
         this._chatInput.embedFonts = false;
         this._chatInput.antiAliasType = AntiAliasType.ADVANCED;
         this._chatInput.textColor = 16777215;
         this._chatInput.defaultTextFormat = new TextFormat("Segoe UI Emoji",14,16777215);
         this._chatPanel.addChild(this._chatInput);
         this._typingLabel = new TextField();
         this._typingLabel.x = 12;
         this._typingLabel.y = 256;
         this._typingLabel.width = 190;
         this._typingLabel.height = 16;
         this._typingLabel.selectable = false;
         this._typingLabel.mouseEnabled = false;
         this._typingLabel.defaultTextFormat = new TextFormat("Verdana",10,65535,false,true);
         this._typingLabel.filters = [new GlowFilter(0,1,2,2,2,1)];
         this._typingLabel.visible = false;
         this._chatPanel.addChild(this._typingLabel);
         this._chatInput.addEventListener(Event.CHANGE,this.onChatInputChange);
         addEventListener(Event.ENTER_FRAME,this.onLobbyEnterFrame);
         this._sendButton = new ButtonUI(this._chatPanel,210,273).setImage(getSendButtonImage()).setSize(30,28) as ButtonUI;
         this.updateLanguage();
         this.showMain();
         this.updatePosition();
      }

      private function makeButton(px:int, py:int) : ButtonUI
      {
         return new ButtonUI(this._panel,px,py).setTextFont(Fonts.ZANTROKE,15,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(Images.BUTTON_SET_AVATAR).setMargin(0,2).setSize(190,49) as ButtonUI;
      }

      override protected function addEventListeners() : void
      {
         super.addEventListeners();
         this._hostButton.addEventListener(MouseEvent.CLICK,this.onHostClick);
         this._joinMenuButton.addEventListener(MouseEvent.CLICK,this.onJoinMenuClick);
         this._connectButton.addEventListener(MouseEvent.CLICK,this.onConnectClick);
         if(this._connectCancelButton != null)
         {
            this._connectCancelButton.addEventListener(MouseEvent.CLICK,this.onConnectCancelClick);
         }
         if(this._connectCloseButton != null)
         {
            this._connectCloseButton.addEventListener(MouseEvent.CLICK,this.onConnectCancelClick);
         }
         if(this._ipValue != null)
         {
            this._ipValue.addEventListener(MouseEvent.CLICK,this.onIpValueClick);
         }
         this._startWorldButton.addEventListener(MouseEvent.CLICK,this.onStartWorldClick);
         this._stopHostButton.addEventListener(MouseEvent.CLICK,this.onStopClick);
         this._disconnectButton.addEventListener(MouseEvent.CLICK,this.onDisconnectClick);
         this._createWorldButton.addEventListener(MouseEvent.CLICK,this.onCreateWorldClick);
         var worldIndex:int = 0;
         while(this._worldButtons != null && worldIndex < this._worldButtons.length)
         {
            this._worldButtons[worldIndex].addEventListener(MouseEvent.CLICK,this.onWorldClick);
            worldIndex++;
         }
         this._blacklistButton.addEventListener(MouseEvent.CLICK,this.onBlacklistClick);
         this._chatToggle.addEventListener(MouseEvent.CLICK,this.onChatToggleClick);
         this._sendButton.addEventListener(MouseEvent.CLICK,this.onChatSendClick);
         this._inviteFriendButton.addEventListener(MouseEvent.CLICK,this.onInviteFriendsClick);
         if(this._closeFriendsButton != null)
         {
            this._closeFriendsButton.addEventListener(MouseEvent.CLICK,this._closeFriendsButton_OnClick);
            if(this._closeFriendsTopButton != null)
            {
               this._closeFriendsTopButton.addEventListener(MouseEvent.CLICK,this._closeFriendsButton_OnClick);
            }
            if(this._prevFriendButton != null)
            {
               this._prevFriendButton.addEventListener(MouseEvent.CLICK,this._onPrevFriendClick);
            }
            if(this._nextFriendButton != null)
            {
               this._nextFriendButton.addEventListener(MouseEvent.CLICK,this._onNextFriendClick);
            }
            if(this._friendsPanel != null)
            {
               this._friendsPanel.addEventListener(MouseEvent.MOUSE_WHEEL,this._onFriendsWheel);
            }
            var friendIndex:int = 0;
            while(friendIndex < this._friendRows.length)
            {
               this._friendRows[friendIndex].addEventListener(MouseEvent.CLICK,this._friendInvite_OnClick);
               friendIndex++;
            }
         }
         if(this._ipBox != null)
         {
            this._ipBox.addEventListener(KeyboardEvent.KEY_DOWN,this.onIpBoxKey);
         }
         if(this._chatInput != null)
         {
            this._chatInput.addEventListener(KeyboardEvent.KEY_DOWN,this.onChatKey);
         }
      }

      override protected function removeEventListeners() : void
      {
         super.removeEventListeners();
         this._hostButton.removeEventListener(MouseEvent.CLICK,this.onHostClick);
         this._joinMenuButton.removeEventListener(MouseEvent.CLICK,this.onJoinMenuClick);
         this._connectButton.removeEventListener(MouseEvent.CLICK,this.onConnectClick);
         if(this._connectCancelButton != null)
         {
            this._connectCancelButton.removeEventListener(MouseEvent.CLICK,this.onConnectCancelClick);
         }
         if(this._connectCloseButton != null)
         {
            this._connectCloseButton.removeEventListener(MouseEvent.CLICK,this.onConnectCancelClick);
         }
         if(this._ipValue != null)
         {
            this._ipValue.removeEventListener(MouseEvent.CLICK,this.onIpValueClick);
         }
         this._startWorldButton.removeEventListener(MouseEvent.CLICK,this.onStartWorldClick);
         this._stopHostButton.removeEventListener(MouseEvent.CLICK,this.onStopClick);
         this._disconnectButton.removeEventListener(MouseEvent.CLICK,this.onDisconnectClick);
         this._inviteFriendButton.removeEventListener(MouseEvent.CLICK,this.onInviteFriendsClick);
         if(this._closeFriendsButton != null)
         {
            this._closeFriendsButton.removeEventListener(MouseEvent.CLICK,this._closeFriendsButton_OnClick);
            if(this._closeFriendsTopButton != null)
            {
               this._closeFriendsTopButton.removeEventListener(MouseEvent.CLICK,this._closeFriendsButton_OnClick);
            }
            if(this._prevFriendButton != null)
            {
               this._prevFriendButton.removeEventListener(MouseEvent.CLICK,this._onPrevFriendClick);
            }
            if(this._nextFriendButton != null)
            {
               this._nextFriendButton.removeEventListener(MouseEvent.CLICK,this._onNextFriendClick);
            }
            if(this._friendsPanel != null)
            {
               this._friendsPanel.removeEventListener(MouseEvent.MOUSE_WHEEL,this._onFriendsWheel);
            }
            var friendIndex:int = 0;
            while(friendIndex < this._friendRows.length)
            {
               this._friendRows[friendIndex].removeEventListener(MouseEvent.CLICK,this._friendInvite_OnClick);
               friendIndex++;
            }
         }
         this._createWorldButton.removeEventListener(MouseEvent.CLICK,this.onCreateWorldClick);
         var worldIndex:int = 0;
         while(this._worldButtons != null && worldIndex < this._worldButtons.length)
         {
            this._worldButtons[worldIndex].removeEventListener(MouseEvent.CLICK,this.onWorldClick);
            worldIndex++;
         }
         if(this._blacklistButton != null)
         {
            this._blacklistButton.removeEventListener(MouseEvent.CLICK,this.onBlacklistClick);
         }
         this._chatToggle.removeEventListener(MouseEvent.CLICK,this.onChatToggleClick);
         this._sendButton.removeEventListener(MouseEvent.CLICK,this.onChatSendClick);
         if(this._ipBox != null)
         {
            this._ipBox.removeEventListener(KeyboardEvent.KEY_DOWN,this.onIpBoxKey);
         }
         if(this._chatInput != null)
         {
            this._chatInput.removeEventListener(KeyboardEvent.KEY_DOWN,this.onChatKey);
            this._chatInput.removeEventListener(Event.CHANGE,this.onChatInputChange);
         }
         removeEventListener(Event.ENTER_FRAME,this.onLobbyEnterFrame);
      }

      override public function dispose() : void
      {
         if(Context.multiplayer != null)
         {
            Context.multiplayer.statusSignal.remove(this.onStatus);
            Context.multiplayer.playersChangedSignal.remove(this.onPlayersChanged);
            Context.multiplayer.chatSignal.remove(this.onIncomingChat);
         }
         super.dispose();
      }

      public function canGoBack() : Boolean
      {
         return this._state != STATE_MAIN;
      }

      public function goBack() : void
      {
         playSound(Sounds.BUTTON_CLICK);
         if(Context.multiplayer != null && Context.multiplayer.active)
         {
            Context.multiplayer.stop();
         }
         if(this._chatOpen)
         {
            this.onChatToggleClick(null);
         }
         this.showMain();
      }

      public function onShow() : void
      {
         this.updateLanguage();
         if(Context.multiplayer != null && Context.multiplayer.isHost)
         {
            this.showHost();
         }
         else if(Context.multiplayer != null && Context.multiplayer.isClient)
         {
            this.showClient();
         }
         else
         {
            this.showMain();
         }
      }

      public function updateLanguage() : void
      {
         if(this._caption != null)
         {
            this._caption.text = loc("title_multiplayer");
         }
         if(this._hostButton != null)
         {
            this._hostButton.text = loc("btn_host");
         }
         if(this._joinMenuButton != null)
         {
            this._joinMenuButton.text = loc("btn_connect");
         }
         if(this._connectButton != null)
         {
            this._connectButton.text = loc("btn_connect");
         }
         if(this._connectCancelButton != null)
         {
            this._connectCancelButton.text = loc("btn_cancel");
         }
         if(this._startWorldButton != null)
         {
            this._startWorldButton.text = loc("btn_start_world");
         }
         if(this._stopHostButton != null)
         {
            this._stopHostButton.text = loc("btn_cancel_lobby");
         }
         if(this._disconnectButton != null)
         {
            this._disconnectButton.text = loc("btn_disconnect");
         }
         if(this._inviteFriendButton != null)
         {
            this._inviteFriendButton.text = loc("btn_invite");
         }
         if(this._worldCaption != null)
         {
            this._worldCaption.text = loc("caption_worlds");
         }
         if(this._createWorldButton != null)
         {
            this._createWorldButton.text = loc("btn_start_world");
         }
         if(this._chatCaption != null)
         {
            this._chatCaption.text = loc("chat_caption");
         }
         if(this._ipLabel != null)
         {
            this._ipLabel.text = loc("lbl_ip");
         }
         if(this._portLabel != null)
         {
            this._portLabel.text = loc("lbl_port");
         }
         this.refreshRoster();
         this.refreshWorldList();
      }

      private function setAllGroupsVisible(main:Boolean, connect:Boolean, host:Boolean, client:Boolean) : void
      {
         this._hostButton.visible = this._hostButton.active = main;
         this._joinMenuButton.visible = this._joinMenuButton.active = main;
         this._ipLabel.visible = connect;
         this._portLabel.visible = connect;
         this._ipBox.visible = this._ipBox.active = connect;
         this._portBox.visible = this._portBox.active = connect;
         this._connectButton.visible = this._connectButton.active = connect;
         if(this._connectCancelButton != null)
         {
            this._connectCancelButton.visible = this._connectCancelButton.active = main || connect;
         }
         if(this._connectCloseButton != null)
         {
            this._connectCloseButton.visible = this._connectCloseButton.active = connect;
         }
         this._ipValue.visible = host || client;
         this._startWorldButton.visible = this._startWorldButton.active = host;
         this._stopHostButton.visible = this._stopHostButton.active = host;
         this._players.visible = host || client;
         if(this._localPlayerLabel != null)
         {
            this._localPlayerLabel.visible = false;
         }
         if(this._clientSubtitle != null)
         {
            this._clientSubtitle.visible = client;
         }
         this._disconnectButton.visible = this._disconnectButton.active = client;
         this._worldCaption.visible = host;
         this._worldNameBox.visible = this._worldNameBox.active = false;
         if(this._nameBoxFrame != null)
         {
            this._nameBoxFrame.visible = false;
         }
         this._createWorldButton.visible = this._createWorldButton.active = false;
         this._worldDetails.visible = host;
         var numWorlds:int = Context.app.getSingleWorlds() != null ? Context.app.getSingleWorlds().length : 0;
         var worldIndex:int = 0;
         while(this._worldButtons != null && worldIndex < this._worldButtons.length)
         {
            var showWorld:Boolean = host && worldIndex < numWorlds;
            this._worldButtons[worldIndex].visible = showWorld;
            this._worldButtons[worldIndex].active = showWorld;
            worldIndex++;
         }
         if(this._rosterGroup != null)
         {
            this._rosterGroup.visible = host || client;
         }
         this._chatToggle.visible = this._chatToggle.active = host || client;
         if(this._blacklistButton != null)
         {
            this._blacklistButton.visible = this._blacklistButton.active = host || client;
         }
         if(!(host || client))
         {
            if(this._chatOpen)
            {
               this.onChatToggleClick(null);
            }
            if(this._blacklistModal != null)
            {
               this._blacklistModal.visible = false;
            }
         }
      }

      private function showMain() : void
      {
         this._state = STATE_MAIN;
         this._status.text = "";
         this._players.text = "";
         this._localPlayerLabel.text = "";
         this._inviteFriendButton.visible = false;
         if(this._friendsModal != null)
         {
            this._friendsModal.visible = false;
         }
         if(this._blacklistModal != null)
         {
            this._blacklistModal.visible = false;
         }
         if(this._friendsPanel != null)
         {
            this._friendsPanel.visible = false;
         }
         this.setAllGroupsVisible(true,false,false,false);
         if(this._caption != null)
         {
            this._caption.setSize(PW,26);
            this._caption.y = 4;
            this._caption.text = Context.app._choosedLanguage == "ru" ? "СЕТЕВАЯ" : "MULTIPLAYER";
            this._caption.visible = true;
         }
         if(this._connectCloseButton != null)
         {
            this._connectCloseButton.visible = this._connectCloseButton.active = false;
         }
         var panelH:int = 170;
         var shelfH:int = 66;
         this._panel.setImage(getHostBackground(panelH,shelfH));
         this._panel.setSize(PW,panelH);
         this._hostButton.setSize(190,49);
         this._joinMenuButton.setSize(190,49);
         this._hostButton.x = 15;
         this._joinMenuButton.x = 221;
         this._hostButton.y = 45;
         this._joinMenuButton.y = 45;
         this._connectCancelButton.x = 118;
         this._connectCancelButton.y = 108;
         this._connectCancelButton.setSize(190,49);
         this._connectCancelButton.text = loc("btn_cancel");
         this.updatePosition();
      }

      private function showConnectMenu() : void
      {
         this._state = STATE_CONNECT_MENU;
         var cw:int = PW;
         var ch:int = 224;
         this._panel.setImage(getHostBackground(ch,70));
         this._panel.setSize(cw,ch);
         if(this._caption != null)
         {
            this._caption.setSize(cw,26);
            this._caption.y = 4;
            this._caption.text = Context.app._choosedLanguage == "ru" ? "ПРИСОЕДИНИТЬСЯ К ЛОББИ" : "JOIN LOBBY";
         }
         if(this._connectCloseButton != null)
         {
            this._connectCloseButton.x = cw - 32;
            this._connectCloseButton.y = 4;
            this._connectCloseButton.visible = this._connectCloseButton.active = true;
         }
         this._status.x = 0;
         this._status.y = 34;
         this._status.setSize(cw,20);
         this._status.text = "";
         this._ipLabel.x = 35;
         this._ipLabel.y = 56;
         this._ipBox.x = 95;
         this._ipBox.y = 52;
         this._ipBox.setSize(290,32);
         this._portLabel.x = 35;
         this._portLabel.y = 96;
         this._portBox.x = 95;
         this._portBox.y = 92;
         this._portBox.setSize(120,32);
         this._connectButton.x = 15;
         this._connectButton.y = 156;
         this._connectButton.setSize(190,49);
         this._connectButton.visible = this._connectButton.active = true;
         this.updatePosition();
         this._inviteFriendButton.visible = false;
         if(this._friendsModal != null)
         {
            this._friendsModal.visible = false;
         }
         if(this._friendsPanel != null)
         {
            this._friendsPanel.visible = false;
         }
         this._status.text = "";
         this._players.text = "";
         if(this._ipBox.text == "" || this._ipBox.text == "0.0.0.0")
         {
            this._ipBox.text = "";
         }
         if(this._portBox.text == "")
         {
            this._portBox.text = "27015";
         }
         this.setAllGroupsVisible(false,true,false,false);
         this._connectCancelButton.x = 221;
         this._connectCancelButton.y = 156;
         this._connectCancelButton.setSize(190,49);
         this._connectCancelButton.text = loc("btn_cancel");
         if(this._connectCloseButton != null)
         {
            this._connectCloseButton.visible = this._connectCloseButton.active = true;
         }
      }

      private function showHost() : void
      {
         this._state = STATE_HOST_LOBBY;
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         if(this._caption != null)
         {
            this._caption.setSize(PW,26);
            this._caption.y = 8;
            this._caption.text = loc("title_multiplayer");
         }
         this._status.x = 0;
         this._status.y = 34;
         this._status.setSize(PW,18);
         this._ipValue.x = 0;
         this._ipValue.y = 52;
         this._ipValue.setSize(PW,18);
         this._players.x = 0;
         this._players.y = 70;
         this._players.setSize(PW,18);
         this._worldCaption.x = 0;
         this._worldCaption.y = 202;
         this._worldCaption.setSize(PW,20);
         this._worldCaption.text = loc("caption_worlds");
         this.layoutHostPanel(Context.app.getSingleWorlds().length);
         var ipText:String = Context.multiplayer != null ? Context.multiplayer.getLocalIPv4All() : "---";
         if(this._startWorldButton != null)
         {
            this._startWorldButton.active = true;
         }
         this._inviteFriendButton.visible = true;
         if(this._friendsModal != null)
         {
            this._friendsModal.visible = false;
         }
         if(this._friendsPanel != null)
         {
            this._friendsPanel.visible = false;
         }
         this._ipValue.text = "IP: " + ipText;
         this._status.text = ru ? "ОЖИДАНИЕ ИГРОКОВ" : "WAITING FOR PLAYERS";
         this.setAllGroupsVisible(false,false,true,false);
         this.refreshWorldList();
         this.refreshRoster();
         this.bindChat();
      }

      private function layoutHostPanel(param1:int) : void
      {
         if(param1 < 1)
         {
            param1 = 1;
         }
         if(param1 > 5)
         {
            param1 = 5;
         }
         var detailsY:int = 224 + param1 * 42 + 2;
         var row1Y:int = detailsY + 38;
         var row2Y:int = row1Y + 55;
         var panelH:int = row2Y + 49 + 18;
         var shelfY:int = row1Y - 8;
         var shelfH:int = panelH - shelfY;
         this._worldDetails.y = detailsY;
         this._startWorldButton.x = 18;
         this._startWorldButton.y = row1Y;
         this._startWorldButton.setSize(190,49);
         this._startWorldButton.setTextFont(Fonts.ZANTROKE,15,16777215);
         this._inviteFriendButton.x = 218;
         this._inviteFriendButton.y = row1Y;
         this._inviteFriendButton.setSize(190,49);
         this._inviteFriendButton.setTextFont(Fonts.ZANTROKE,15,16777215);
         this._stopHostButton.x = 118;
         this._stopHostButton.y = row2Y;
         this._stopHostButton.setSize(190,49);
         this._stopHostButton.setTextFont(Fonts.ZANTROKE,15,16777215);
         this._panel.setImage(getHostBackground(panelH,shelfH));
         this._panel.setSize(PW,panelH);
         this.updatePosition();
      }

      private function showClient() : void
      {
         this._state = STATE_CLIENT_LOBBY;
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         if(this._caption != null)
         {
            this._caption.setSize(PW,26);
            this._caption.y = 8;
            this._caption.text = loc("title_multiplayer");
         }
         var panelH:int = 330;
         var shelfH:int = 78;
         this._panel.setImage(getHostBackground(panelH,shelfH));
         this._panel.setSize(PW,panelH);
         this.updatePosition();
         this._status.x = 0;
         this._status.y = 34;
         this._status.setSize(PW,18);
         this._status.text = loc("connected_to_host");
         if(this._clientSubtitle != null)
         {
            this._clientSubtitle.visible = true;
            this._clientSubtitle.text = loc("waiting_host_start");
         }
         var srvHost:String = Context.multiplayer != null && Context.multiplayer.connectedHost.length > 0 ? Context.multiplayer.connectedHost : (this._ipBox != null && this._ipBox.text.length > 0 ? this._ipBox.text : "---");
         var srvPort:int = Context.multiplayer != null && Context.multiplayer.connectedPort > 0 ? Context.multiplayer.connectedPort : 27015;
         this._ipValue.x = 0;
         this._ipValue.y = 72;
         this._ipValue.setSize(PW,18);
         this._ipValue.text = (ru ? "СЕРВЕР: " : "SERVER: ") + srvHost + ":" + srvPort;
         this._players.x = 0;
         this._players.y = 90;
         this._players.setSize(PW,18);
         this._disconnectButton.x = 118;
         this._disconnectButton.y = 260;
         this._disconnectButton.setSize(190,49);
         this._disconnectButton.text = loc("btn_disconnect");
         this._inviteFriendButton.visible = false;
         if(this._friendsModal != null)
         {
            this._friendsModal.visible = false;
         }
         if(this._friendsPanel != null)
         {
            this._friendsPanel.visible = false;
         }
         this.setAllGroupsVisible(false,false,false,true);
         this.refreshRoster();
         this.bindChat();
      }

      private function onRosterKickClick(e:MouseEvent) : void
      {
         var btn:ButtonUI = e.currentTarget as ButtonUI;
         if(btn == null || btn.tag == null)
         {
            return;
         }
         var pid:int = int(btn.tag);
         if(pid > 1 && Context.multiplayer != null && Context.multiplayer.isHost)
         {
            playSound(Sounds.BUTTON_CLICK);
            btn.active = false;
            Context.multiplayer.kickPlayer(pid);
         }
      }

      private function onRosterBanClick(e:MouseEvent) : void
      {
         var btn:ButtonUI = e.currentTarget as ButtonUI;
         if(btn == null || btn.tag == null)
         {
            return;
         }
         var pid:int = int(btn.tag);
         if(pid > 1 && Context.multiplayer != null && Context.multiplayer.isHost)
         {
            playSound(Sounds.BUTTON_CLICK);
            btn.active = false;
            Context.multiplayer.banPlayer(pid);
         }
      }

      private function refreshRoster() : void
      {
         if(Context.multiplayer == null)
         {
            return;
         }
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         var isHost:Boolean = this._state == STATE_HOST_LOBBY;
         var isClient:Boolean = this._state == STATE_CLIENT_LOBBY;
         if(!isHost && !isClient)
         {
            if(this._rosterGroup != null)
            {
               this._rosterGroup.visible = false;
            }
            return;
         }
         this._rosterGroup.visible = true;
         var players:Array = Context.multiplayer.getPlayerList();
         var count:int = int(players.length);
         if(count < 1)
         {
            count = 1;
         }
         if(this._players != null)
         {
            if(isHost)
            {
               this._players.text = loc("host_port_players") + count + "/4";
            }
            else
            {
               this._players.text = loc("players_count") + count + "/4";
            }
         }
         var i:int = 0;
         while(i < 4)
         {
            var panel:Sprite = this._rosterSlotPanels[i];
            var lbl:LabelUI = this._rosterSlotLabels[i];
            var kickBtn:ButtonUI = this._rosterKickButtons[i];
            var banBtn:ButtonUI = this._rosterBanButtons[i];
            if(isHost)
            {
               panel.y = 90 + i * 27;
            }
            else
            {
               panel.y = 112 + i * 32;
            }
            if(i < players.length)
            {
               var p:Object = players[i];
               var pId:int = int(p.id);
               var pName:String = String(p.name);
               var pIsHost:Boolean = Boolean(p.isHost);
               var pIsMe:Boolean = Boolean(p.isMe);
               var roleText:String = "";
               if(pIsHost && pIsMe)
               {
                  roleText = loc("roster_host_you");
               }
               else if(pIsHost)
               {
                  roleText = loc("roster_host");
               }
               else if(pIsMe)
               {
                  roleText = loc("roster_you");
               }
               if(!pIsHost && Boolean(p.isOperator))
               {
                  roleText += " [OP]";
               }
               lbl.text = i + 1 + ". " + pName + roleText;
               lbl.setFont(Fonts.ZANTROKE,13,pIsHost ? 16766240 : (pIsMe ? 8119435 : 16777215));
               if(kickBtn != null)
               {
                  if(isHost && !pIsHost && !pIsMe)
                  {
                     kickBtn.visible = true;
                     kickBtn.active = true;
                     kickBtn.tag = String(pId);
                     kickBtn.text = loc("btn_kick");
                     if(banBtn != null)
                     {
                        banBtn.visible = true;
                        banBtn.active = true;
                        banBtn.tag = String(pId);
                        banBtn.text = loc("btn_ban");
                     }
                  }
                  else
                  {
                     kickBtn.visible = false;
                     kickBtn.active = false;
                     kickBtn.tag = null;
                     if(banBtn != null)
                     {
                        banBtn.visible = false;
                        banBtn.active = false;
                        banBtn.tag = null;
                     }
                  }
               }
            }
            else
            {
               lbl.text = i + 1 + ". " + loc("roster_empty");
               lbl.setFont(Fonts.ZANTROKE,12,7315624);
               if(kickBtn != null)
               {
                  kickBtn.visible = false;
                  kickBtn.active = false;
                  kickBtn.tag = null;
               }
               if(banBtn != null)
               {
                  banBtn.visible = false;
                  banBtn.active = false;
                  banBtn.tag = null;
               }
            }
            i++;
         }
      }

      private function bindChat() : void
      {
         if(Context.multiplayer != null)
         {
            Context.multiplayer.chatSignal.remove(this.onIncomingChat);
            Context.multiplayer.chatSignal.add(this.onIncomingChat);
            this._chatText.text = "";
         }
      }

      private function setFriendsModalHostControlsVisible(val:Boolean) : void
      {
      }

      private function redrawFriendsPanelBackground() : void
      {
      }

      private function onBlacklistClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         if(this._blacklistModal == null)
         {
            this.createBlacklistPanel();
            this.addBlacklistPanelListeners();
         }
         this._blacklistPage = 0;
         this.fillBlacklistPanel();
         this._blacklistModal.visible = true;
         if(this._blacklistPanel != null)
         {
            this._blacklistPanel.visible = true;
         }
         this.updatePosition();
      }

      private function closeBlacklist(e:MouseEvent = null) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         if(this._blacklistModal != null)
         {
            this._blacklistModal.visible = false;
         }
      }

      private function createBlacklistPanel() : void
      {
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         this._blacklistModal = new Sprite();
         this._blacklistModal.visible = false;
         this.addChild(this._blacklistModal);
         this._blacklistPanel = new Sprite();
         this._blacklistModal.addChild(this._blacklistPanel);
         this._blacklistPanel.graphics.beginFill(664106,1);
         this._blacklistPanel.graphics.drawRoundRect(0,0,PW,455,12,12);
         this._blacklistPanel.graphics.endFill();
         this._blacklistPanel.addChild(new Bitmap(getFriendsBackground()));
         var title:LabelUI = new LabelUI(this._blacklistPanel,10,4).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setVerticalAlign(LabelUI.MIDDLE_ALIGN).setText(loc("blacklist_title")).setFont(Fonts.ZANTROKE,16,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(PW - 50,30) as LabelUI;
         this._closeBlacklistTopButton = new ButtonUI(this._blacklistPanel,PW - 32,3).setImage(Images.BUTTON_GAME_INVENTORY_EXIT).setSize(28,28) as ButtonUI;
         this._blacklistRows = new Vector.<ButtonUI>(4,true);
         this._blacklistNickLabels = new Vector.<LabelUI>(4,true);
         this._blacklistIpLabels = new Vector.<LabelUI>(4,true);
         this._blacklistRowEntries = [];
         var r:int = 0;
         while(r < 4)
         {
            var rowFrameY:int = 40 + r * 48;
            this._blacklistPanel.graphics.lineStyle(1,1984592,0.8);
            this._blacklistPanel.graphics.beginFill(1323062,0.6);
            this._blacklistPanel.graphics.drawRoundRect(14,rowFrameY,PW - 28,44,6,6);
            this._blacklistPanel.graphics.endFill();
            this._blacklistNickLabels[r] = new LabelUI(this._blacklistPanel,24,rowFrameY + 4).setAutoSize(false).setFont(Fonts.ZANTROKE,13,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(270,20) as LabelUI;
            this._blacklistIpLabels[r] = new LabelUI(this._blacklistPanel,24,rowFrameY + 24).setAutoSize(false).setSystemFont("Verdana",10,8965341).setSize(270,16) as LabelUI;
            this._blacklistRows[r] = new ButtonUI(this._blacklistPanel,PW - 124,rowFrameY + 6).setText(loc("blacklist_unban")).setTextFont(Fonts.ZANTROKE,11,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,106,32)).setMargin(0,2).setSize(106,32) as ButtonUI;
            this._blacklistRows[r].visible = false;
            r++;
         }
         this._blacklistEmptyLabel = new LabelUI(this._blacklistPanel,20,115).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setVerticalAlign(LabelUI.MIDDLE_ALIGN).setText(loc("blacklist_empty")).setFont(Fonts.ZANTROKE,14,8954024).setSize(PW - 40,30) as LabelUI;
         this._blacklistPrevButton = new ButtonUI(this._blacklistPanel,120,236).setText("<").setTextFont(Fonts.ZANTROKE,15,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,44,34)).setMargin(0,2).setSize(44,34) as ButtonUI;
         this._blacklistPageLabel = new LabelUI(this._blacklistPanel,168,236).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setVerticalAlign(LabelUI.MIDDLE_ALIGN).setFont(Fonts.ZANTROKE,14,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(90,34) as LabelUI;
         this._blacklistNextButton = new ButtonUI(this._blacklistPanel,262,236).setText(">").setTextFont(Fonts.ZANTROKE,15,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,44,34)).setMargin(0,2).setSize(44,34) as ButtonUI;
         var manualTitle:LabelUI = new LabelUI(this._blacklistPanel,20,280).setAutoSize(false).setSystemFont("Verdana",11,11197934).setText(loc("blacklist_manual_title")).setSize(PW - 40,18) as LabelUI;
         var inputBg:Sprite = new Sprite();
         inputBg.x = 20;
         inputBg.y = 302;
         inputBg.graphics.beginFill(1054752,0.95);
         inputBg.graphics.lineStyle(2,1802908,1,true);
         inputBg.graphics.drawRoundRect(0,0,260,32,8,8);
         inputBg.graphics.endFill();
         inputBg.graphics.lineStyle(1,2470358,1,true);
         inputBg.graphics.drawRoundRect(1,1,258,30,6,6);
         this._blacklistPanel.addChild(inputBg);
         this._blacklistManualInput = new TextField();
         this._blacklistManualInput.x = 24;
         this._blacklistManualInput.y = 306;
         this._blacklistManualInput.width = 252;
         this._blacklistManualInput.height = 24;
         this._blacklistManualInput.type = TextFieldType.INPUT;
         this._blacklistManualInput.selectable = true;
         this._blacklistManualInput.mouseEnabled = true;
         this._blacklistManualInput.tabEnabled = true;
         this._blacklistManualInput.maxChars = 64;
         this._blacklistManualInput.embedFonts = false;
         this._blacklistManualInput.antiAliasType = AntiAliasType.ADVANCED;
         this._blacklistManualInput.textColor = 16777215;
         this._blacklistManualInput.defaultTextFormat = new TextFormat("Segoe UI Emoji",13,16777215);
         this._blacklistPanel.addChild(this._blacklistManualInput);
         this._blacklistManualButton = new ButtonUI(this._blacklistPanel,290,302).setText(loc("btn_ban")).setTextFont(Fonts.ZANTROKE,12,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_GAME_INVENTORY_RED_BIG,114,32)).setMargin(0,2).setSize(114,32) as ButtonUI;
         var note:LabelUI = new LabelUI(this._blacklistPanel,12,350).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setText(loc("blacklist_note")).setSystemFont("Verdana",11,16769439).setSize(PW - 24,22) as LabelUI;
         this._closeBlacklistButton = new ButtonUI(this._blacklistPanel,(PW - 160) * 0.5,394).setText(loc("friends_btn_close")).setTextFont(Fonts.ZANTROKE,14,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,160,44)).setMargin(0,2).setSize(160,44) as ButtonUI;
      }

      private function addBlacklistPanelListeners() : void
      {
         this._closeBlacklistButton.addEventListener(MouseEvent.CLICK,this.closeBlacklist);
         if(this._closeBlacklistTopButton != null)
         {
            this._closeBlacklistTopButton.addEventListener(MouseEvent.CLICK,this.closeBlacklist);
         }
         if(this._blacklistPrevButton != null)
         {
            this._blacklistPrevButton.addEventListener(MouseEvent.CLICK,this._onPrevBlacklistClick);
         }
         if(this._blacklistNextButton != null)
         {
            this._blacklistNextButton.addEventListener(MouseEvent.CLICK,this._onNextBlacklistClick);
         }
         if(this._blacklistModal != null)
         {
            this._blacklistModal.addEventListener(MouseEvent.CLICK,this._onBlacklistModalBackdropClick);
         }
         if(this._blacklistManualButton != null)
         {
            this._blacklistManualButton.addEventListener(MouseEvent.CLICK,this._onManualBanClick);
         }
         if(this._blacklistManualInput != null)
         {
            this._blacklistManualInput.addEventListener(KeyboardEvent.KEY_DOWN,this._onManualBanKeyDown);
         }
         var i:int = 0;
         while(i < 4)
         {
            this._blacklistRows[i].addEventListener(MouseEvent.CLICK,this._onUnbanRowClick);
            i++;
         }
      }

      private function _onBlacklistModalBackdropClick(e:MouseEvent) : void
      {
         if(e.target == this._blacklistModal)
         {
            this.closeBlacklist(e);
         }
      }

      private function fillBlacklistPanel() : void
      {
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         var list:Array = Context.multiplayer != null ? Context.multiplayer.getBlacklist() : [];
         var total:int = list != null ? list.length : 0;
         var totalPages:int = Math.max(1,Math.ceil(total / 4));
         if(this._blacklistPage < 0)
         {
            this._blacklistPage = 0;
         }
         if(this._blacklistPage >= totalPages)
         {
            this._blacklistPage = totalPages - 1;
         }
         this._blacklistPageLabel.text = this._blacklistPage + 1 + " / " + totalPages;
         this._blacklistPrevButton.active = this._blacklistPage > 0;
         this._blacklistNextButton.active = this._blacklistPage < totalPages - 1;
         if(total == 0)
         {
            this._blacklistEmptyLabel.visible = true;
            var k:int = 0;
            while(k < 4)
            {
               this._blacklistRows[k].visible = false;
               this._blacklistNickLabels[k].text = "";
               this._blacklistIpLabels[k].text = "";
               k++;
            }
            return;
         }
         this._blacklistEmptyLabel.visible = false;
         this._blacklistRowEntries = [];
         var startIdx:int = this._blacklistPage * 4;
         var r:int = 0;
         while(r < 4)
         {
            var idx:int = startIdx + r;
            if(idx < total)
            {
               var entry:Object = list[idx];
               this._blacklistRowEntries[r] = idx;
               this._blacklistRows[r].visible = true;
               this._blacklistRows[r].tag = String(idx);
               var nStr:String = entry.nick != null && entry.nick.length > 0 ? entry.nick : loc("blacklist_no_nick");
               this._blacklistNickLabels[r].text = nStr;
               var ipStr:String = entry.ip != null && entry.ip.length > 0 ? "IP: " + entry.ip : "";
               var reasonStr:String = entry.reason != null && entry.reason.length > 0 ? " (" + entry.reason + ")" : "";
               this._blacklistIpLabels[r].text = ipStr + reasonStr;
            }
            else
            {
               this._blacklistRows[r].visible = false;
               this._blacklistNickLabels[r].text = "";
               this._blacklistIpLabels[r].text = "";
            }
            r++;
         }
      }

      private function _onUnbanRowClick(e:MouseEvent) : void
      {
         var btn:ButtonUI = e.currentTarget as ButtonUI;
         if(btn == null || btn.tag == null)
         {
            return;
         }
         var idx:int = int(btn.tag);
         playSound(Sounds.BUTTON_CLICK);
         if(Context.multiplayer != null)
         {
            Context.multiplayer.removeBanByIndex(idx);
         }
         this.fillBlacklistPanel();
      }

      private function _onManualBanClick(e:MouseEvent) : void
      {
         if(this._blacklistManualInput == null)
         {
            return;
         }
         var val:String = this._blacklistManualInput.text;
         if(val == null)
         {
            return;
         }
         val = val.replace(/^\s+|\s+$/g,"");
         if(val.length == 0)
         {
            return;
         }
         playSound(Sounds.BUTTON_CLICK);
         if(Context.multiplayer != null)
         {
            var isIp:Boolean = /^[\d\.\:]+$/.test(val);
            if(isIp)
            {
               Context.multiplayer.addBan("",val,"Manual");
            }
            else
            {
               Context.multiplayer.addBan(val,"","Manual");
            }
         }
         this._blacklistManualInput.text = "";
         this.fillBlacklistPanel();
      }

      private function _onManualBanKeyDown(e:KeyboardEvent) : void
      {
         if(e.keyCode == 13)
         {
            this._onManualBanClick(null);
         }
      }

      private function _onPrevBlacklistClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         --this._blacklistPage;
         this.fillBlacklistPanel();
      }

      private function _onNextBlacklistClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         ++this._blacklistPage;
         this.fillBlacklistPanel();
      }

      private function onInviteFriendsClick(param1:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         if(this._friendsModal == null)
         {
            this.createFriendsPanel();
            this.addFriendsPanelListeners();
         }
         this.fillFriendsPanel();
         this._friendsModal.visible = true;
         if(this._friendsPanel != null)
         {
            this._friendsPanel.visible = true;
         }
         this.updatePosition();
      }

      private function createFriendsPanel() : void
      {
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         this._friendsModal = new Sprite();
         this._friendsModal.visible = false;
         this.addChild(this._friendsModal);
         this._friendsPanel = new Sprite();
         this._friendsModal.addChild(this._friendsPanel);
         this._friendsPanel.graphics.beginFill(664106,1);
         this._friendsPanel.graphics.drawRoundRect(0,0,PW,455,12,12);
         this._friendsPanel.graphics.endFill();
         this._friendsPanel.addChild(new Bitmap(getFriendsBackground()));
         var r:int = 0;
         while(r < 5)
         {
            var rowFrameY:int = 40 + r * 51;
            this._friendsPanel.graphics.lineStyle(1,1984592,0.8);
            this._friendsPanel.graphics.beginFill(1323062,0.6);
            this._friendsPanel.graphics.drawRoundRect(14,rowFrameY,PW - 28,48,6,6);
            this._friendsPanel.graphics.endFill();
            r++;
         }
         var title:LabelUI = new LabelUI(this._friendsPanel,10,4).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setVerticalAlign(LabelUI.MIDDLE_ALIGN).setText(loc("friends_title")).setFont(Fonts.ZANTROKE,16,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(PW - 50,30) as LabelUI;
         this._closeFriendsTopButton = new ButtonUI(this._friendsPanel,PW - 32,3).setImage(Images.BUTTON_GAME_INVENTORY_EXIT).setSize(28,28) as ButtonUI;
         this._friendRows = new Vector.<ButtonUI>(5,true);
         this._friendNames = new Vector.<LabelUI>(5,true);
         this._friendIds = [];
         var i:int = 0;
         while(i < 5)
         {
            var rowY:int = 40 + i * 51;
            this._friendNames[i] = new LabelUI(this._friendsPanel,24,rowY).setAutoSize(false).setVerticalAlign(LabelUI.MIDDLE_ALIGN).setSystemFont("Verdana",13,16777215).setSize(240,48) as LabelUI;
            this._friendRows[i] = new ButtonUI(this._friendsPanel,280,rowY + 5).setText(loc("friends_btn_invite")).setTextFont(Fonts.ZANTROKE,13,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,120,38)).setMargin(0,2).setSize(120,38) as ButtonUI;
            this._friendRows[i].tag = i;
            this._friendRows[i].visible = false;
            i++;
         }
         this._prevFriendButton = new ButtonUI(this._friendsPanel,110,300).setText("<").setTextFont(Fonts.ZANTROKE,16,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,48,38)).setMargin(0,2).setSize(48,38) as ButtonUI;
         this._friendPageLabel = new LabelUI(this._friendsPanel,164,300).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setVerticalAlign(LabelUI.MIDDLE_ALIGN).setFont(Fonts.ZANTROKE,15,16777215).addFilter(UIStyle.BLACK_STROKE_FILTER).setSize(96,38) as LabelUI;
         this._nextFriendButton = new ButtonUI(this._friendsPanel,266,300).setText(">").setTextFont(Fonts.ZANTROKE,16,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,48,38)).setMargin(0,2).setSize(48,38) as ButtonUI;
         this._friendsNote = new LabelUI(this._friendsPanel,12,348).setAutoSize(false).setAlign(LabelUI.CENTER_ALIGN).setSystemFont("Verdana",11,16769439).setSize(PW - 24,22) as LabelUI;
         this._closeFriendsButton = new ButtonUI(this._friendsPanel,(PW - 160) * 0.5,394).setText(loc("friends_btn_close")).setTextFont(Fonts.ZANTROKE,14,16777215).setTextFilters(UIStyle.BLACK_STROKE_FILTER).setImage(createSlicedButton(Images.BUTTON_SET_AVATAR,160,44)).setMargin(0,2).setSize(160,44) as ButtonUI;
      }

      private function addFriendsPanelListeners() : void
      {
         this._closeFriendsButton.addEventListener(MouseEvent.CLICK,this._closeFriendsButton_OnClick);
         if(this._closeFriendsTopButton != null)
         {
            this._closeFriendsTopButton.addEventListener(MouseEvent.CLICK,this._closeFriendsButton_OnClick);
         }
         if(this._prevFriendButton != null)
         {
            this._prevFriendButton.addEventListener(MouseEvent.CLICK,this._onPrevFriendClick);
         }
         if(this._nextFriendButton != null)
         {
            this._nextFriendButton.addEventListener(MouseEvent.CLICK,this._onNextFriendClick);
         }
         if(this._friendsPanel != null)
         {
            this._friendsPanel.addEventListener(MouseEvent.MOUSE_WHEEL,this._onFriendsWheel);
         }
         if(this._friendsModal != null)
         {
            this._friendsModal.addEventListener(MouseEvent.CLICK,this._onFriendsModalBackdropClick);
         }
         var i:int = 0;
         while(i < 5)
         {
            this._friendRows[i].addEventListener(MouseEvent.CLICK,this._friendInvite_OnClick);
            i++;
         }
      }

      private function _onFriendsModalBackdropClick(e:MouseEvent) : void
      {
         if(e.target == this._friendsModal)
         {
            this._closeFriendsButton_OnClick(e);
         }
      }

      private function fillFriendsPanel() : void
      {
         var j:int;
         var fid:String;
         var fn:String;
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         var sw:* = Context.app.Steamworks;
         var total:int = 0;
         this._cachedFriends = [];
         try
         {
            total = int(sw.getFriendCount(4));
            j = 0;
            while(j < total)
            {
               fid = sw.getFriendByIndex(j,4);
               if(fid != null)
               {
                  fn = sw.getFriendPersonaName(fid);
                  this._cachedFriends.push({
                     "id":fid,
                     "name":(fn != null && fn.length > 0 ? fn : "Steam Friend " + (j + 1))
                  });
               }
               j++;
            }
         }
         catch(e:Error)
         {
            this._cachedFriends = [];
         }
         this._friendPage = 0;
         this.refreshFriendPage();
      }

      private function refreshFriendPage() : void
      {
         var ru:Boolean = Context.app._choosedLanguage == "ru";
         var totalItems:int = int(this._cachedFriends.length);
         var totalPages:int = Math.max(1,Math.ceil(totalItems / 5));
         if(this._friendPage >= totalPages)
         {
            this._friendPage = totalPages - 1;
         }
         if(this._friendPage < 0)
         {
            this._friendPage = 0;
         }
         this._friendPageLabel.text = this._friendPage + 1 + " / " + totalPages;
         this._prevFriendButton.enabled = this._friendPage > 0;
         this._nextFriendButton.enabled = this._friendPage < totalPages - 1;
         var startIdx:int = this._friendPage * 5;
         var i:int = 0;
         while(i < 5)
         {
            var itemIdx:int = startIdx + i;
            if(itemIdx < totalItems)
            {
               var f:Object = this._cachedFriends[itemIdx];
               this._friendIds[i] = f.id;
               this._friendNames[i].text = f.name;
               this._friendRows[i].visible = true;
            }
            else
            {
               this._friendIds[i] = null;
               this._friendNames[i].text = totalItems == 0 ? loc("friends_no_friends") : "";
               this._friendRows[i].visible = false;
            }
            i++;
         }
         if(totalItems == 0)
         {
            this._friendsNote.text = loc("friends_note_none");
         }
         else
         {
            this._friendsNote.text = loc("friends_note_normal");
         }
      }

      private function _onPrevFriendClick(param1:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         if(this._friendPage > 0)
         {
            --this._friendPage;
            this.refreshFriendPage();
         }
      }

      private function _onNextFriendClick(param1:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         var totalPages:int = Math.max(1,Math.ceil(this._cachedFriends.length / 5));
         if(this._friendPage < totalPages - 1)
         {
            ++this._friendPage;
            this.refreshFriendPage();
         }
      }

      private function _onFriendsWheel(param1:MouseEvent) : void
      {
         var totalPages:int = Math.max(1,Math.ceil(this._cachedFriends.length / 5));
         if(param1.delta < 0)
         {
            if(this._friendPage < totalPages - 1)
            {
               ++this._friendPage;
               this.refreshFriendPage();
            }
         }
         else if(param1.delta > 0)
         {
            if(this._friendPage > 0)
            {
               --this._friendPage;
               this.refreshFriendPage();
            }
         }
      }

      private function _friendInvite_OnClick(param1:MouseEvent) : void
      {
         var _loc2_:int;
         var _loc3_:String;
         var _loc4_:Boolean;
         var ipToCopy:String;
         playSound(Sounds.BUTTON_CLICK);
         _loc2_ = int((param1.currentTarget as ButtonUI).tag);
         _loc3_ = this._friendIds != null && _loc2_ < this._friendIds.length ? this._friendIds[_loc2_] as String : null;
         _loc4_ = Context.app._choosedLanguage == "ru";
         ipToCopy = "";
         if(Context.multiplayer != null)
         {
            ipToCopy = Context.multiplayer.getLocalIPv4();
            if(ipToCopy == null || ipToCopy.length < 3 || ipToCopy == "0.0.0.0")
            {
               ipToCopy = Context.multiplayer.getLocalIPv4All();
            }
         }
         if(ipToCopy == null || ipToCopy.length == 0 || ipToCopy == "0.0.0.0")
         {
            ipToCopy = "127.0.0.1";
         }
         try
         {
            Clipboard.generalClipboard.clear();
            Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT,ipToCopy);
         }
         catch(e1:Error)
         {
         }
         try
         {
            System.setClipboard(ipToCopy);
         }
         catch(e2:Error)
         {
         }
         if(this._friendsNote != null)
         {
            this._friendsNote.text = loc("friends_copied_ip") + ipToCopy;
         }
         if(_loc3_ != null)
         {
            try
            {
               Context.app.Steamworks.activateGameOverlayToUser("chat",_loc3_);
            }
            catch(overlayError:Error)
            {
            }
         }
      }

      private function _closeFriendsButton_OnClick(param1:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         if(this._friendsModal != null)
         {
            this._friendsModal.visible = false;
         }
      }

      private function onIncomingChat(msg:String) : void
      {
         this._chatText.appendText(msg + "\n");
         this._chatText.scrollV = this._chatText.maxScrollV;
      }

      private function onChatToggleClick(e:MouseEvent) : void
      {
         if(e != null)
         {
            playSound(Sounds.BUTTON_CLICK);
         }
         this._chatOpen = !this._chatOpen;
         this._chatPanel.visible = this._chatOpen;
         this._chatToggle.setImage(getChatArrowImage(this._chatOpen));
         this.updatePosition();
         if(this._chatOpen)
         {
            this.focusChatInput();
         }
      }

      private function onHostClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         Context.app.prepareActiveProfile();
         Context.multiplayer.startHost(27015);
         showHost();
      }

      private function onJoinMenuClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         this.showConnectMenu();
      }

      private function onIpBoxKey(e:KeyboardEvent) : void
      {
         if(e.keyCode == 13)
         {
            this.onConnectClick(null);
         }
      }

      private function onChatKey(e:KeyboardEvent) : void
      {
         if(e.keyCode == 13)
         {
            e.preventDefault();
            e.stopPropagation();
            this.sendChatMessage();
         }
         else if(Context.multiplayer != null)
         {
            Context.multiplayer.sendTyping(true);
         }
      }

      private function onChatSendClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         this.sendChatMessage();
      }

      private function sendChatMessage() : void
      {
         var msg:String = this._chatInput.text.replace(/^\s+|\s+$/g,"");
         if(Context.multiplayer != null)
         {
            Context.multiplayer.sendTyping(false);
         }
         if(msg.length == 0)
         {
            this.focusChatInput();
            return;
         }
         if(Context.multiplayer != null && Context.multiplayer.active)
         {
            var nick:String = this.getSavedNickname();
            var selfPrefix:String = Context.app._choosedLanguage == "ru" ? "Вы" : "You";
            if(Context.multiplayer.sendChat(msg))
            {
               this.onIncomingChat(selfPrefix + " (" + nick + "): " + msg);
            }
            this._chatInput.text = "";
         }
         this.focusChatInput();
      }

      private function onChatInputChange(e:Event) : void
      {
         if(Context.multiplayer != null)
         {
            Context.multiplayer.sendTyping(true);
         }
      }

      private function onLobbyEnterFrame(e:Event) : void
      {
         if(this._typingLabel != null && Context.multiplayer != null)
         {
            var tTxt:String = Context.multiplayer.getTypingText();
            if(tTxt != this._typingLabel.text)
            {
               this._typingLabel.text = tTxt;
            }
            this._typingLabel.visible = tTxt.length > 0;
         }
      }

      private function focusChatInput() : void
      {
         if(this.stage != null && this._chatInput != null)
         {
            this.stage.focus = this._chatInput;
            this._chatInput.setSelection(this._chatInput.length,this._chatInput.length);
         }
      }

      private function getSavedNickname() : String
      {
         var nick:String = "";
         if(Context.savedCustomize != null && Context.savedCustomize.name != null)
         {
            nick = String(Context.savedCustomize.name);
         }
         else if(Context.cachedPlayerData != null && Context.cachedPlayerData.name != null)
         {
            nick = String(Context.cachedPlayerData.name);
         }
         if(nick.length == 0 || nick == "Player")
         {
            var so:SharedObject = SharedObject.getLocal("test");
            if(so.data.nickname != null)
            {
               nick = String(so.data.nickname);
            }
         }
         nick = nick.replace(/^\s+|\s+$/g,"");
         return nick.length > 0 ? nick : "Player";
      }

      private function updateLocalPlayerLabel() : void
      {
         var prefix:String = Context.app._choosedLanguage == "ru" ? "ВЫ" : "YOU";
         this._localPlayerLabel.text = prefix + " (" + this.getSavedNickname() + ")";
      }

      private function onConnectCancelClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         if(this._state == STATE_MAIN)
         {
            if(Context.app != null && Context.app.lobby != null)
            {
               Context.app.lobby.showHomePage();
            }
         }
         else
         {
            this.showMain();
         }
      }

      private function onIpValueClick(e:MouseEvent) : void
      {
         var ipToCopy:String;
         var isLanCopy:Boolean;
         var vpn:String;
         var lan:String;
         var ru:Boolean;
         var typeLabel:String;
         playSound(Sounds.BUTTON_CLICK);
         ipToCopy = "";
         isLanCopy = false;
         if(Context.multiplayer != null)
         {
            vpn = Context.multiplayer.getLocalIPv4();
            lan = Context.multiplayer.getLanIPv4();
            if(vpn != lan && this._copyLanNext)
            {
               ipToCopy = lan;
               isLanCopy = true;
               this._copyLanNext = false;
            }
            else
            {
               ipToCopy = vpn;
               if(vpn != lan)
               {
                  this._copyLanNext = true;
               }
            }
         }
         if(ipToCopy == null || ipToCopy.length == 0 || ipToCopy == "0.0.0.0")
         {
            ipToCopy = "127.0.0.1";
         }
         try
         {
            Clipboard.generalClipboard.clear();
            Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT,ipToCopy);
         }
         catch(e1:Error)
         {
         }
         try
         {
            System.setClipboard(ipToCopy);
         }
         catch(e2:Error)
         {
         }
         ru = Context.app._choosedLanguage == "ru";
         typeLabel = isLanCopy ? " (LAN)" : (Context.multiplayer != null && Context.multiplayer.getLocalIPv4() != Context.multiplayer.getLanIPv4() ? " (VPN)" : "");
         this._status.text = (ru ? "СКОПИРОВАН IP" : "COPIED IP") + typeLabel + ": " + ipToCopy;
      }

      private function onConnectClick(e:MouseEvent) : void
      {
         if(e != null)
         {
            playSound(Sounds.BUTTON_CLICK);
         }
         var ip:String = this._ipBox.text.replace(/^\s+|\s+$/g,"");
         var port:int = int(parseInt(this._portBox.text));
         if(ip.indexOf(":") >= 0)
         {
            var parts:Array = ip.split(":");
            ip = parts[0].replace(/^\s+|\s+$/g,"");
            if(parts.length > 1)
            {
               var pNum:int = int(parseInt(parts[1]));
               if(pNum > 0 && pNum <= 65535)
               {
                  port = pNum;
                  this._portBox.text = String(port);
               }
            }
            this._ipBox.text = ip;
         }
         if(ip == null || ip.length < 3)
         {
            this._status.text = Context.app._choosedLanguage == "ru" ? "ВВЕДИТЕ IP" : "ENTER IP";
            return;
         }
         if(isNaN(port) || port <= 0 || port > 65535)
         {
            port = 27015;
         }
         this._connectButton.active = false;
         this._status.text = Context.app._choosedLanguage == "ru" ? "ПОДКЛЮЧЕНИЕ..." : "CONNECTING...";
         Context.app.prepareActiveProfile();
         Context.multiplayer.connect(ip,port);
      }

      private function onCreateWorldClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         var _loc2_:Object = Context.app.createMultiplayerWorld(this._worldNameBox.text);
         if(_loc2_ == null)
         {
            this._status.text = Context.app._choosedLanguage == "ru" ? "МАКСИМУМ 5 МИРОВ" : "MAXIMUM 5 WORLDS";
            return;
         }
         this._worldNameBox.text = "";
         this.refreshWorldList();
      }

      private function onWorldClick(e:MouseEvent) : void
      {
         var _loc2_:ButtonUI = e.currentTarget as ButtonUI;
         if(_loc2_ == null || _loc2_.tag == null)
         {
            return;
         }
         playSound(Sounds.BUTTON_CLICK);
         var curTag:String = String(_loc2_.tag);
         Context.app.selectSingleWorld(curTag);
         this.refreshWorldList();
      }

      private function refreshWorldList() : void
      {
         var _loc1_:Array = Context.app.getSingleWorlds();
         var _loc2_:Object = Context.app.getSelectedSingleWorld();
         if(_loc2_ == null && _loc1_ != null && _loc1_.length > 0)
         {
            _loc2_ = _loc1_[0];
         }
         var _loc5_:int = 0;
         while(_loc5_ < this._worldButtons.length)
         {
            var _loc6_:ButtonUI = this._worldButtons[_loc5_];
            if(_loc1_ != null && _loc5_ < _loc1_.length)
            {
               var _loc4_:Object = _loc1_[_loc5_];
               var isSel:Boolean = _loc2_ != null && String(_loc4_.id) == String(_loc2_.id);
               _loc6_.visible = true;
               _loc6_.active = true;
               _loc6_.tag = String(_loc4_.id);
               _loc6_.text = (isSel ? "> " : "  ") + (_loc5_ + 1) + ": " + String(_loc4_.name).toUpperCase();
               _loc6_.x = 43;
               _loc6_.y = 224 + _loc5_ * 42;
               _loc6_.setSize(340,38);
            }
            else
            {
               _loc6_.visible = false;
               _loc6_.active = false;
               _loc6_.tag = null;
            }
            _loc5_++;
         }
         var numWorlds:int = _loc1_ != null ? _loc1_.length : 0;
         if(this._state == STATE_HOST_LOBBY)
         {
            this.layoutHostPanel(numWorlds);
         }
         var _loc7_:Boolean = Context.app._choosedLanguage == "ru";
         if(_loc2_ != null)
         {
            this._worldDetails.text = loc("created") + this.formatWorldDate(Number(_loc2_.createdAt)) + "   " + loc("modified") + this.formatWorldDate(Number(_loc2_.modifiedAt)) + "\n" + loc("last_played") + (Number(_loc2_.lastPlayedAt) > 0 ? this.formatWorldDate(Number(_loc2_.lastPlayedAt)) : "---");
         }
         else
         {
            this._worldDetails.text = "";
         }
      }

      private function formatWorldDate(param1:Number) : String
      {
         var _loc2_:Date = new Date(param1);
         return this.twoDigits(_loc2_.date) + "." + this.twoDigits(_loc2_.month + 1) + "." + _loc2_.fullYear + " " + this.twoDigits(_loc2_.hours) + ":" + this.twoDigits(_loc2_.minutes);
      }

      private function twoDigits(param1:int) : String
      {
         return param1 < 10 ? "0" + param1 : param1.toString();
      }

      private function onStartWorldClick(e:MouseEvent) : void
      {
         playSound(Sounds.BUTTON_CLICK);
         this._startWorldButton.active = false;
         this._status.text = Context.app._choosedLanguage == "ru" ? "ЗАПУСК..." : "STARTING...";
         Context.app.startMultiplayerHostGame();
      }

      private function onStopClick(e:MouseEvent) : void
      {
         this.goBack();
      }

      private function onDisconnectClick(e:MouseEvent) : void
      {
         this.goBack();
      }

      private function onStatus(s:String) : void
      {
         if(this._state == STATE_HOST_LOBBY)
         {
            this._status.text = s;
         }
         else if(this._state == STATE_CONNECT_MENU || this._state == STATE_CLIENT_LOBBY)
         {
            this._status.text = s;
            if(s.indexOf("CONNECTED AS PLAYER ") == 0 || s == "SYNCING WORLD..." || s == "RECEIVING WORLD...")
            {
               this.showClient();
            }
            else if(s == "CONNECTION FAILED" || s == "DISCONNECTED" || s.indexOf("KICKED BY HOST") == 0 || s == "GAME ALREADY STARTED" || s.indexOf("PROTOCOL VERSION MISMATCH") == 0 || s.indexOf("MULTIPLAYER VERSION MISMATCH") == 0)
            {
               if(this._state == STATE_CLIENT_LOBBY)
               {
                  this.showMain();
               }
               else
               {
                  this._connectButton.active = true;
               }
            }
         }
      }

      private function onPlayersChanged(count:int) : void
      {
         this.refreshRoster();
      }

      override protected function onStageResize() : void
      {
         if(this.stage != null)
         {
            setSize(this.stage.stageWidth,this.stage.stageHeight);
            this.updatePosition();
         }
      }

      private function updatePosition() : void
      {
         if(this.stage != null && this._panel != null)
         {
            this._panel.x = this.stage.stageWidth * 0.5 - this._panel.width * 0.5;
            this._panel.y = this.stage.stageHeight * 0.5 - this._panel.height * 0.5;
            if(this._chatOpen && this._chatPanel != null)
            {
               this._panel.x -= 125;
               this._chatPanel.x = this._panel.x + PW + 10;
               this._chatPanel.y = this._panel.y;
            }
         }
         if(this.stage != null && this._friendsModal != null && this._friendsModal.visible)
         {
            this._friendsModal.graphics.clear();
            this._friendsModal.graphics.beginFill(0,0.65);
            this._friendsModal.graphics.drawRect(0,0,this.stage.stageWidth,this.stage.stageHeight);
            this._friendsModal.graphics.endFill();
            if(this._friendsPanel != null)
            {
               this._friendsPanel.x = int((this.stage.stageWidth - PW) * 0.5);
               this._friendsPanel.y = int((this.stage.stageHeight - 455) * 0.5);
            }
         }
         if(this.stage != null && this._blacklistModal != null && this._blacklistModal.visible)
         {
            this._blacklistModal.graphics.clear();
            this._blacklistModal.graphics.beginFill(0,0.65);
            this._blacklistModal.graphics.drawRect(0,0,this.stage.stageWidth,this.stage.stageHeight);
            this._blacklistModal.graphics.endFill();
            if(this._blacklistPanel != null)
            {
               this._blacklistPanel.x = int((this.stage.stageWidth - PW) * 0.5);
               this._blacklistPanel.y = int((this.stage.stageHeight - 455) * 0.5);
            }
         }
      }
   }
}
