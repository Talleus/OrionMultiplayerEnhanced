package orion.worlds.entities
{
   import orion.inventories.CharacterInventory;

   public final class RemotePlayerEntity extends ControlCharacterEntity
   {

      private var _inputFlags:int;

      private var _targetX:Number;

      private var _targetY:Number;

      private var _targetVX:Number;

      private var _targetVY:Number;

      private var _hasTarget:Boolean;

      public var networkPlayerId:int;

      public var respawnTimer:int;

      public function RemotePlayerEntity(param1:int, param2:Boolean)
      {
         super();
         this.networkPlayerId = param1;
         networkId = param1;
         networkReplica = param2;
         useNetworkAim = true;
         this.setInventory(new CharacterInventory());
         name = "Player " + param1;
      }

      public function applyProfile(param1:Object) : void
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.name != null)
         {
            name = String(param1.name);
         }
         if(param1.gender !== undefined)
         {
            gender = Boolean(param1.gender);
         }
         if(param1.hair !== undefined)
         {
            hairIndex = int(param1.hair);
         }
         if(param1.head !== undefined)
         {
            headIndex = int(param1.head);
         }
         if(param1.hair_color !== undefined)
         {
            hairColorIndex = int(param1.hair_color);
         }
         if(param1.level !== undefined)
         {
            level = int(param1.level);
         }
         if(param1.another_data != null)
         {
            if(param1.another_data.items != null)
            {
               inventory.load(param1.another_data);
            }
            if(param1.another_data.item_in_hand !== undefined)
            {
               inventory.itemInHandIndex = int(param1.another_data.item_in_hand);
            }
            if(param1.another_data.health !== undefined)
            {
               health = int(param1.another_data.health);
            }
         }
         initHairAndHeadTextures();
      }

      public function setInputState(param1:int, param2:Number, param3:Number, param4:int) : void
      {
         this._inputFlags = param1;
         networkHeadDegrees = param2;
         networkArmDegrees = param3;
         if(inventory != null)
         {
            inventory.itemInHandIndex = param4;
         }
      }

      public function setReplicaState(param1:Number, param2:Number, param3:Number, param4:Number, param5:int, param6:int, param7:int, param8:Number, param9:Number, param10:int, param11:Boolean, param12:int) : void
      {
         this._targetX = param1;
         this._targetY = param2;
         this._targetVX = param3;
         this._targetVY = param4;
         this._hasTarget = true;
         direction = param5;
         bodyFrame = param6;
         handFrame = param7;
         networkHeadDegrees = param8;
         networkArmDegrees = param9;
         health = param10;
         alive = param11;
         if(inventory != null)
         {
            inventory.itemInHandIndex = param12;
         }
      }

      public function resetAt(param1:Number, param2:Number) : void
      {
         reset();
         setPosition(param1,param2);
         this._targetX = param1;
         this._targetY = param2;
         this._hasTarget = true;
         respawnTimer = 0;
      }

      override public function creatureAttacking(param1:int, param2:CreatureEntity) : void
      {
         var _loc3_:Boolean = alive;
         super.creatureAttacking(param1,param2);
         if(Context.multiplayer != null)
         {
            Context.multiplayer["onPlayerDamagedByPlayer"](this,param2,_loc3_);
         }
      }

      override public function projectileAttacking(param1:int, param2:ProjectileEntity) : void
      {
         var _loc3_:Boolean = alive;
         super.projectileAttacking(param1,param2);
         if(Context.multiplayer != null)
         {
            Context.multiplayer["onPlayerDamagedByPlayer"](this,param2 == null ? null : param2.owner,_loc3_);
         }
      }

      override public function update(param1:int) : void
      {
         if(networkReplica)
         {
            this.updateReplica(param1);
            return;
         }
         this.upControl = (this._inputFlags & 1) != 0;
         this.downControl = (this._inputFlags & 2) != 0;
         this.leftControl = (this._inputFlags & 4) != 0;
         this.rightControl = (this._inputFlags & 8) != 0;
         this.jumpControl = (this._inputFlags & 0x10) != 0;
         super.update(param1);
      }

      private function updateReplica(param1:int) : void
      {
         if(!this._hasTarget)
         {
            return;
         }
         var _loc2_:Number = Math.min(1,param1 / 80);
         position.x += (this._targetX - position.x) * _loc2_;
         position.y += (this._targetY - position.y) * _loc2_;
         velocity.x = this._targetVX;
         velocity.y = this._targetVY;
         renderPosition.x = Math.round(position.x);
         renderPosition.y = Math.round(position.y);
         center.x = position.x + width * 0.5;
         center.y = position.y + height * 0.5;
         updateBuffsEffects(param1);
         if(inventory != null)
         {
            if(this.currentItemStack != this.inventory.items[this.inventory.itemInHandIndex])
            {
               this.itemInHand = null;
               this.currentItemStack = this.inventory.items[this.inventory.itemInHandIndex];
               if(this.activeItemInHand != null)
               {
                  this.activeItemInHand.removed();
                  this.activeItemInHand = null;
               }
               if(this.currentItemStack != null)
               {
                  this.itemInHand = this.currentItemStack.item;
                  if(this.itemInHand.activeItem != null)
                  {
                     this.activeItemInHand = new this.itemInHand.activeItem(this,this.currentItemStack);
                     this.activeItemInHand.added();
                  }
               }
            }
         }
         if(this.activeItemInHand != null)
         {
            this.activeItemInHand.update(param1);
         }
      }
   }
}
