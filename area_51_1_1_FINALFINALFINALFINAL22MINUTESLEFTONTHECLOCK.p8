pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
--hazmat havoc by archonic,
--virtuavirtue, pico-8 gamer

last_checkpoint = {8, 184}
spawn = {8, 184}
--spawn = {94*8, 19*8}
--spawn = {90*8, 10*8}
msets = {}

function reset_ents()
	for xy in all(msets) do
	 mset(xy[1], xy[2], 5)
	end
end

-- main
	-- initialize
function _init()
	--screen shake
	if break_room then 
	 reset_ents() 
	 msets = {}
	 spawn = {744, 80}
	 mset(94, 10, 33) --axe
	 mset(117, 13, 37) -- crowbar
	 mset(123, 13, 96) --medkit
	end
	intensity = 0
	shake_fall_factor = 0.8
	camera_override = false
	logs,ticks,points,fading,fadespeed,bg_col
	=
	{},0,{},0,5,5
	--camera corners
	camera_corners = {{0,0}, {1024,1024}}
	_init_keycards()
	_real_game_keycards_init()
	init_dialogue()
	_init_interact_events()
	_ent_init()
	_obj_init()
	
	--ply=new_ent(8,176,1) -- player
	ply = new_ent(spawn[1], spawn[2], 1)
	px,py=ui_pos()[1],ui_pos()[2]
	palt(0,false)
	palt(15,true)
	
	poke(24364,3)
	place_objects()
	_cutscenes_init()
	form_poke(1,0)
	light=1
	if break_room then _init_br() end

	if not break_room then
	  add_dscene(create_dscene("i can't believe", "i dropped my", "keys down", "here...", "well, might as", "well go", "look for them!", "", "🅾️ - interact", "arrows - move"))
	  add_dscene(create_dscene("i need keycards", "to get around", "this place,", "though.", "i think i", "smelled the 1st", "one up north..."))
	end
end

function ui_pos()
	return {
		mid(ply.x-32, camera_corners[1][1], camera_corners[2][1]) + (rnd()-0.5)*intensity,
		mid(ply.y-32, camera_corners[1][2], camera_corners[2][2]) + (rnd()-0.5)*intensity
	}
end

function update_screen_shake()
 intensity *= shake_fall_factor
 if intensity < 0.1 then intensity = 0 end
end
	-- update game
function _update()
 if gamefinished then return end
	if light~=6then
		fade_in=fade_in and fade_in+1 or 0
		
		if fade_in%5==0then
			light+=1
			form_poke(light,0)
		end
	end
	
	fire_loc_funcs()
		-- update each object's head bob
	obj_bob = sin(t())/2
	camera_override = false
	if update_sequence() then
		goto finally
	end
	if break_room then
	if #enemies_waiting > 0 then br_alert_check() end
	if #enemies_alerted > 0 then update_alerted() end
	end
			--	handle dialogue
	 dialogueing=update_dialogue()
	 if not dialogueing then
	   --★ place all game update code here! ★
				-- update each entitiy
			foreach(ents,function(ent)
			 if not ent.dead then
				ent:ai()
				ent.iframes = max(ent.iframes and (ent.iframes - 1) or 0)
					if ent.attacking == true then
						for damagee in all(get_targeted_ents(ent)) do
							damage_ent(damagee, ent.item.dmg)
							if not (ent.item and ent.item.ind == 1) then
								ent.attacking = false
								break
							end
						end
					end
				end
			end)
			fire_tile_interactions()
	 end
	::finally::
		-- player ui position
		if not camera_override then
		 local uipos = ui_pos()
		 px = uipos[1]
		 py = uipos[2]
	 end
end

function draw_hopscotch(y_off)
	--in that one room
	for i=1,7 do
		local x = i*6 + hro[1] - 5
	 if i % 2 == 0 then
	 	rect(x, hro[2] - 5 + y_off, x + 4, hro[2] - 1 + y_off, 7)
	 	rect(x, hro[2] + 5 + y_off, x + 4, hro[2] + 1 + y_off, 7) 
  else
			rect(x, hro[2] + y_off, x + 4, hro[2] + 4 + y_off, 7)
		end
	end
end

	-- draw
function _draw()
 if gamefinished then
 	cls(0)
 	print("hazmat havoc", px+12, py+4, 10)
 	draw_rotation(ply, false)
 	print("created by:", px+14, py + 36, 6)
 	print("virtuavirtue", px+12, py + 42,7 )
 	print("archonic", px+12, py + 48,7 )
 	print("pico-8 gamer", px+12, py + 54,7 )

 	return
 end
	cls(bg_col)
	update_screen_shake()
	map()
	
		-- move camera
	camera(px + (camera_override and (rnd()-0.5)*intensity or 0), py + (camera_override and (rnd()-0.5)*intensity or 0))
	-- ui
	healthbar()
	keycard_ui()
		-- draw entities
	if break_room then draw_hopscotch(0) draw_hopscotch(24) end
	foreach(ents,_draw_ent)
		-- draw objects
	foreach(objs,_draw_obj)
	
	
		-- debugging
		-- draw points
	--foreach(points, function(point)
		--pset(point[1], point[2], point[3])
	--end)
	points = {}
	-- draw dialogue
	if dialogueing then
		draw_dialogue()
	end
	draw_sequence()
	draw_alerted()
end

function apply_pal(cols)
	for pair in all(cols) do
		pal(pair[1], pair[2])
	end
end

function reset_pal(cols)
	for pair in all(cols) do
		pal(pair[1], pair[1])
	end
end


function q(x, steps) --rounds x to the nearest 1/steps
	return flr(x*steps)/steps
end

		-- spawn items
	-- index - item sprite
	-- [1] - item index in array
	-- [2] - 1|item - 2|enemy
obj_inds={}
obj_inds[33]='1,1' -- axe
obj_inds[37]='2,1' -- crowbar
obj_inds[41]='3,1' -- gun
obj_inds[96]='4,1' -- medkit
obj_inds[101]='5,1' -- white keycard
obj_inds[97]='6,1'
obj_inds[99]='7,1'
obj_inds[100]="8,1"
obj_inds[98]="9,1"

	-- spawn enemies
obj_inds[5]='2,2' -- slimer



-->8
-- entity class

	-- draw entitiy
function _draw_ent(ent)
	draw_rotation(ent)
end


	-- create entity
function new_ent(x,y,ai)
	local ent={}
	local entdata = ent_arr[ai]
	ent.x,ent.y,ent.sprs,ent.ai,ent.z,ent.dh,ent.dv,ent.spd,ent.org_x,ent.org_y,ent.iframes,ent.iframes_max
	=
	x,y,split(ent_arr[ai][1]),ent_arr[ai][3],0,1,0,0,x,y,0,entdata.iframes
	if entdata.atk_len then --if they have this they have all the other atkvals
		ent.atk_len,ent.atk_rot_add,ent.attacking,ent.atk_ticks,ent.rest_window=
		entdata.atk_len,nil,false,0, entdata.rest_window
	end
	local stats=split(ent_arr[ai][2])
	ent.hp,ent.max_spd
	=
	stats[1],entdata.spd
	
	add(ents,ent)
	return ent
end


	-- initialize entities
function _ent_init()
	ents={}
end


		-- - collision -
	-- point colliding
function point_colliding_w_map(x, y)
	return fget(mget(x/8, y/8), 0)
end


	-- colliding y
function ent_colliding_w_map_y(x,y,w, h,xvel, yvel)
 local yorg = (yvel > 0) and y+h or y
	for i=x,x+w-8,8 do
  if point_colliding_w_map(i, yorg) or
     point_colliding_w_map(i+7, yorg) then
      --snap collision
      return true
  end
 end
 return false
end


	-- colliding x
function ent_colliding_w_map_x(x,y,w,h,xvel,yvel)
	 local xorg = (xvel > 0) and x+w or x
	 for i=y,y+h-8,8 do
	  if point_colliding_w_map(xorg, i) or
	     point_colliding_w_map(xorg, i+7) then
	     return true end
	 end
	 return false
end


	-- any collision
function ent_collision_w_map(x, y, w, h, xvel, yvel)		
		--plot points along x axis
	 if ent_colliding_w_map_x(x+xvel, y+yvel, w, h, xvel, yvel) then xvel = 0 end
	 if ent_colliding_w_map_y(x+xvel, y+yvel, w, h, xvel, yvel) then yvel = 0 end
  return {x+xvel, y+yvel}
end


	-- if flag at tile
function flag_at(x,y,flag)
	return fget(tile_at(x,y),flag)
end

	-- get tile at position
function tile_at(x,y)
	return mget(x,y)
end

function dhdv(z)
 z = q(z, 8)
	z = (z+0.125)*8
	key = {{1, 0}, {1,1}, {0, -1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, 1}, {1, -1}}
	return key[z]
end

		-- ✽ entities ✽ --
	-- array of entities
ent_arr={
		-- player
	{'1,2,3','3',
		function(ent)
		if can_atk(ent) then
 	  if btnp(❎) then start_atk(ent) 
 	  elseif btnp(1, 1) then
 	  	ent.z = 0
 	  	start_atk(ent)
 	  elseif btnp(0, 1) then
 	  	ent.z = 0.5
 	  	start_atk(ent)
 	  elseif btnp(2, 1) then
 	   ent.z = 0.25
 	   start_atk(ent)
 	  elseif btnp(3, 1) then
 	   ent.z = 0.75
 	   start_atk(ent)
    end
   end
				-- control
			
				-- move + collision check
	 	move_ent(ent)
			control_ent(ent, true)
			if ent.atk_ticks > 0 then
				update_atk(ent)
			end
				-- check if player can pick up items
			pick_up(ent,true)
			
			local x,y
			=
			(ent.x+4)/8,(ent.y+4)/8
			local cur_tile=tile_at(x,y)
			local pals=tile_pals[cur_tile]
			
				-- check if player on trigger tile
			if pals then
				if type(pals)=="function"then
					pals(x,y,ent)
				else
					bg_col=pals
				end
			end
		end
	,spd=2,rest_window = 1,atk_len=8,iframes=20},
	
		-- slimer
	{
		'5,6,7','1',
		 -- update
		function(ent)
				-- ai
			control_ent(ent)
			
				-- move + collision check
			move_ent(ent)
			
				-- pick up items
			pick_up(ent)
		end
	,spd=1,atk_len=10,rest_window=10}
}


		-- - utility -
	-- distance
function dist(x1,y1,x2,y2)
  return abs(x1-x2)+abs(y1-y2)
end

	-- damage entity
function damage_ent(ent,amm)
		-- damage sound
	if ent.iframes > 0 then return end
	local watcher = get_watcher(ent)
	if not (watcher == nil) then 
	 for ent in all(watcher.entities) do
	 	alert_enemy(ent)
  end
	end
	-- damage entity on interval
	sfx(ent==ply and 4 or 1)
	ent.hp=max(ent.hp-amm)
	ent.iframes = (ent.iframes_max or 25)
	if ent.hp==0 then
	 if ent == ply then
	  if break_room then
		 	ply.x = 93*8
		 	ply.y = 10*8
		 	_init()
		 else
		  ply.x = last_checkpoint[1]
		 	ply.y = last_checkpoint[2]
	 	end
	 	ply.hp = 2
  else
			del(ents,ent)
			ent.dead=true
			ent.spd = 0
		 if ent.persist then --break roojm
		  persist_enemies_left -= 1
		  if persist_enemies_left <= 0 then
		   unlock_doors()
	   end
		 end
	 end
	end
end


		-- ai/player modules -
	-- check if player or entity can pick up item
function pick_up(ent,but)
 if not (ent == ply) then return end
		-- run checks
	for obj in all(objs) do
		if (dist(obj.x, obj.y, ent.x, ent.y) < 10) and not (obj.owner == ent) and btnp(🅾️) then
				-- make sure enemies can't take from player
			if(not but and (ent.item or obj.owner or ent.ammo==-2))break
			sfx(2)
			
				-- auto use
			if obj.type==1 then
				obj.use(obj,ent)
				return
			end
			
				-- drop current item
			if(ent.item)drop_item(ent)
				-- replace current object owner
			if(obj.owner)obj.owner.item=nil

			obj.owner=ent
			
				-- sort it to front of rendering table
			del(objs,obj)
			add(objs,obj)
			ent.item=obj
			return
		end
	end
	
	
		-- update player item
	if ent.item then
			-- update item stats
		update_player_item(ent)
		
			-- check for buttons
		if but then
				-- throw item
			if btnp(❎,1)then 
				drop_item(ent)
			elseif btnp(❎)then
				ent.item.use(ent.item,ent)
			end
		end
	end
end

atk_rot_speed = 1.3/30

--update attack values (called while attacking)
function update_atk(ent)
	ent.atk_ticks -= 1
	ent.atk_rot_add = (ent.atk_rot_add + atk_rot_speed) % 1
	if abs(ent.atk_rot_add - ent.z) <= atk_rot_speed then
	  ent.atk_rot_add = ent.z
	end
 if ent.attacking then
		if ent.atk_ticks <= 0 then 
		 ent.attacking = false 
		 ent.atk_ticks = ent.rest_window
	 end
 elseif ent.atk_ticks <= 0 then
 	ent.atk_rot_add = nil
 end
end

function can_atk(ent)
	return ent.atk_ticks <= 0 and ent.item
end

--start atk
function start_atk(ent)
	ent.atk_ticks = ent.atk_len
	ent.atk_rot_add = (ent.z - 0.25) % 1
	ent.attacking = true
end

	-- move
function move_ent(ent)
		-- direction
	if ent.spd>0.01then
		local dir_x,dir_y
		=
		cos(ent.z_dir)*ent.spd,sin(ent.z_dir)*ent.spd
		
			-- collision
		local loc=ent_collision_w_map(ent.x,ent.y,8,8,dir_x,dir_y)
	 
	 	-- movement
	 ent.x=loc[1]
	 ent.y=loc[2]
	end
end

atk_reach = 7.5

function ent_is_targeted(ent, xy)
	local x = mid(ent.x, xy[1], ent.x+(ent.w or 8))
	local y = mid(ent.y, xy[2], ent.y+(ent.h or 8))

	return x==xy[1] and y==xy[2]
end

function get_targeted_ents(ent)
 local atk_reach = (ent.item and ent.item.ind == 1) and atk_reach*0.7 or atk_reach
 local targeted = {}
	local point = get_point_ahead(ent,atk_reach)
	local point2 = get_point_ahead(ent, atk_reach*0.5)
	for target in all(ents) do
		if not (target == ent) then 
		 if ent_is_targeted(target, point) or ent_is_targeted(target, point2) then
		 	add(targeted, target)
   end
		end
	end
	return targeted
end

-- get ent from spawned tile
function get_spawned_ent(org_mx, org_my)
  for ent in all(ents) do
    if ent.org_x\8 == org_mx and ent.org_y\8 == org_my then
	  return ent
	end
  end
end

	-- control entity
function control_ent(ent,but)
 if ent.locked then return end
			-- init
	local ph,pv,dh,dv,but
	=
	false,false,false,false,but or false
		-- player ai
	if but then
			-- handle movement presses
		if(btn(1)) then ph=1 end
		if(btn(0))ph=-1
		if(btn(2))pv=-1
		if(btn(3))pv=1
		
			-- handle look presses
		if ent.atk_ticks > 0 then
			local dh_dv = dhdv(ent.z)
			dh,dv = dh_dv[1],dh_dv[2]
		else
			if(btn(1))dh=1
			if(btn(0))dh=-1
			if(btn(2))dv=-1
			if(btn(3))dv=1
		end
			-- if look direction pressed
		if dh or dv then 
			if not (ent.atk_ticks > 0) then ent.z=atan2(dh,dv) end
			ent.dh,ent.dv
			=
			dh or 0,dv or 0
		end
		
			-- if movement direction pressed
		if ph or pv then
		 ent.z_dir,ent.ph,ent.pv
		 =
		 atan2(ph,pv),ph or 0,pv or 0
	 	
	 		-- accel
	 	accel_ent(ent)
	 	
	 		-- footstep sound effect
	 	ent.walk_tick=ent.walk_tick and ent.walk_tick+1 or 0
	 	if ent.walk_tick%7==0then
	 		sfx(6)
	 	end
	 	
	 		-- slow player
		else
			accel_ent(ent,true)
		end
	
		return
		
		
			-- enemy ai
	else
		dist_ply=dist(ent.x,ent.y,ply.x,ply.y)
		
			-- check if player in range
		if (dist_ply<30 or ent.persist) and not ply.dead then
				-- damage player
			if dist_ply<6 then
				damage_ent(ply,(break_room and 0.5 or 0.3))
				return
			end
		
				-- handle target position
			if(ent.x>ply.x+3)ph=-1
			if(ent.x<ply.x-3)ph=1
			if(ent.y<ply.y-3)pv=1
			if(ent.y>ply.y+3)pv=-1
		
		else
			ph,pv
			=
			0,0
		end
	
			-- move enemy
		if(ph!=0)or(pv!=0)then
			ent.dh,ent.dv
			=
			ph or 0,pv or 0
			
		 ent.z=atan2(ph,pv)
		 ent.z_dir=atan2(ent.dh,ent.dv)
		 
			accel_ent(ent)		 	
 	
 		-- slow entity
		else
			accel_ent(ent,true)
		end
		
		return
	end
end


	-- accelerate entity
function accel_ent(ent,bool)
	bool=bool or false
	
	if not bool then
		ent.spd=mid(0, ent.spd+.1, ent.max_spd)
		logs = {}
		add(logs, ent.spd)
	else
		ent.spd=max(ent.spd-.1)
	end
	if ent == ply and ent.spd > 0 then
		
	end
end


		-- - collision -
	-- point colliding
function point_colliding_w_map(x, y)
	return fget(mget(x/8, y/8), 0)
end

	--this value narrows collision by po pixels
po = 2


	-- ent colliding y
function ent_colliding_w_map_y(x,y,w, h,xvel, yvel)
 local yorg=(yvel>0)and y+h-po or y+po
 	
 	-- point offsets in order to narrow collision
	for i=x,x+w-8,8 do
  if point_colliding_w_map(i+po, yorg) or
     point_colliding_w_map(i+7-po, yorg) then
      	--snap collision
      return true
  end
 end
 return false
end


	-- ent colliding x
function ent_colliding_w_map_x(x,y,w,h,xvel,yvel)
	 local xorg=(xvel>0)and x+w-po or x+po
	 
	 for i=y,y+h-8,8 do
	  if point_colliding_w_map(xorg, i+po) or
	     point_colliding_w_map(xorg, i+7-po) then
	     return true end
	 end
	 return false
end


	--loc is x or y, vel is assoc. velocity
function snapvel(loc, vel) --snap collision deprecated
 return 0
end


	-- entity collision with map
function ent_collision_w_map(x, y, w, h, xvel, yvel)		
		--plot points along x axis
	 if ent_colliding_w_map_x(x+xvel, y, w, h, xvel, yvel) then xvel = snapvel(x, xvel) end
	 if ent_colliding_w_map_y(x, y+yvel, w, h, xvel, yvel) then yvel = snapvel(y, yvel) end
  return {x+xvel, y+yvel}
end

-->8
-- object class
	-- create entity
	
function new_obj(x,y,ind)
	local obj={}
	local index=objects[ind]
	
	local sprs=split(index[1])
	local data=split(index[2])
	
	obj.x,obj.y,obj.sprs,obj.use,obj.z,obj.ammo,obj.type,obj.name,obj.ind,obj.cols,obj.dmg
	=
	x,y,sprs,index[3],0.125,data[2],data[3],data[1],ind,index.cols,index.dmg
	obj.org_frame=obj.frame
	
	if obj.ammo<0 then
		obj.z=0
	end
	
	add(objs,obj)
	return obj
end


	-- initialize entities
function _obj_init()
	objs={}
	obj_bob = 0
end


	-- draw objects
function _draw_obj(obj)
	local r = false
 if not (obj.cols == nil) then
  apply_pal(obj.cols)
		r = true
 end
	draw_rotation(obj, (obj.owner == nil))
	if r then reset_pal(obj.cols) end
end

function keycard_func(ind)
	local func = function(obj, entity)
		collect(obj.ind) --todo does this work
		local keycards_left = keycards_left()
		if keycards_left == 0 then
		 sfx(12)
			add_dscene(create_dscene("oh look...","that was the","last one..."))
			add_dscene(create_dscene("now i can", "unlock those", "gates...", "", "yay..."))
		elseif keycards_left == 3 then
		 sfx(9)
		 add_dscene(create_dscene("a keycard!", "now to make", "my way to", "that " .. keycard_name_map[obj.ind], "gate!"))
		elseif keycards_left == 2 then
		 sfx(9)
		elseif keycards_left == 1 then
			sfx(9)
			--add_dscene(create_dscene("hey look!", "the cards that", "i didn't get!"))
			--add_dscene(create_dscene("i mean...", "i would've", "gotten them...", "", "if i didn't", "bust open this", "break room..."))
			--add_dscene(create_dscene("i almost", "feel bad", "for the poor", "guys..."))
		end
		del(objs, obj)
	end
	return func
end

	-- objects array
	-- object type structure
	-- 1: str: sprite number(s) separated by commas for rotatable sprites
	-- 2: str: param collection, first is name. rest: who nose!!
	-- 3: use function: called when the object is used
	-- cols: an array of color pairs (2 item arrs) to be swapped on draw
objects={
		-- fire axe (1)
	{'32,33,34,35','fire axe,1,0',
			-- use
		function(obj,ent)
			melee(obj,ent)
		end
	,dmg=1},
	
		-- crowbar (2)
	{'36,37,38,39','crowbar,1,0',
			-- use
		function(obj,ent)
			melee(obj,ent)
			-- box destruction is in tab 5
		end
	,dmg=0.5},
	
		-- pistol (3)
	{'40,41,42,43','gun,10,0',
			-- use
		function(obj,ent)
		
		end
	},
	
		-- medkit (4)
	{'96','medkit,-1,1',
			-- use
		function(obj,ent)
			ent.hp+=2
			del(objs,obj)
		end
	},
	
		-- 5 white keycard (enemies can't take)
	{'101','tutorial_keycard,-2,1',
			-- use
		function(obj,ent)
			keycards_collected[1]=true
			del(objs,obj)
			
			if not gate_unlocked then
				gate_unlocked = true
				sfx(9)
				add_dscene(create_dscene("who left","this keycard","lying around?"))
				mset(x,y,0)
				return
			end
		end
	},
	{'97','red_keycard,-2,1', --6 red keycard
			keycard_func(6)
	},
	{'99','green_keycard,-2,1', --7 green keycard
			keycard_func(7)
	},
	{'100','orange_keycard,-2,1', --8 orange keycard
			keycard_func(8)
	},
	{'98','blue_keycard,-2,1', --9 blue keycard
			keycard_func(9)
	},
}


		-- - utility -
	-- drop item
function drop_item(ent)
	ent.item.owner,ent.item
	=
	nil,nil
end


	-- update player's item
function update_player_item(ent)
	local obj
	=
	ent.item
	
	obj.x,obj.y,obj.z
	=
	ent.x+ent.dh*5,ent.y+ent.dv*5,ent.z
end


	-- initiate melee swing
function melee(obj,ent)
	if can_atk(ent) then
		start_atk(ent)
	end
end


	-- spawn items and enemies
function place_objects()
	for x=0,128do
		for y=0,32do
			local mg=mget(x,y)
			local obj=split(obj_inds[mg])
			
				-- spawn item at position
			if obj then
				if obj[2]==1then
					new_obj(x*8,y*8,obj[1])
					mset(x,y,254)
				else
					new_ent(x*8,y*8,obj[1])
					mset(x,y,0)
				end
			end
		end
	end
end
-->8
-- dialogue system

	-- variables
char_len=4
line_spacing=6
box_size_max=29
side_margin=4
box_speed=3
max_lines=3


	-- dialogue init
function init_dialogue()
 box_size=0
 current_dialogue=nil
 dialogue_queue={}
 dialogueing=false
end


	-- create dialogue scene
function create_dscene(...)
	local table=pack(...)
	local dscene={lines={}}
	for i,lin in ipairs(table)do
		add(dscene.lines,{str=lin,x=33-(char_len*#lin\2),y=line_spacing*(i-0.4)})
	end
	return dscene
end


	-- add dialogue scene
function add_dscene(dscene)
	if current_dialogue==nil then
		current_dialogue=dscene
	else 
		add(dialogue_queue,dscene)
	end
end


	-- update dialogue scene
function update_dscene(dscene, advance)
	if advance then
		sfx(11)
		deli(dscene.lines, 1)
		if #dscene.lines == 0 then return true
		elseif #dscene.lines == max_lines-1 then
			deli(dscene.lines, 1)
			return true
		else
		 for lin in all(dscene.lines) do
		 	lin.y -= line_spacing
   end
		 return false 
		end
	end
end


		-- update dialogue
	-- should be called every frame. returns true if dialogue is active
function update_dialogue()
	if current_dialogue==nil then
		if box_size>0 then box_size=max(box_size-box_speed,0)
		else return false end
		return true
	else
		if box_size>=box_size_max then
			if update_dscene(current_dialogue,btnp(🅾️))then
				current_dialogue=dialogue_queue[1]
				if #dialogue_queue>0then deli(dialogue_queue,1)end
			end
		else
			box_size=min(box_size+box_speed,box_size_max)
		end
		return true
	end
end


	-- draw dialogue
function draw_dialogue()
	local box_edge = py + box_size
 line(px, box_edge-1,px+64,box_edge-1, 6)
 line(px, box_edge,px+64,box_edge, 7)
 rectfill(px,py,px+64, box_edge-2, 1)
 
 	-- code that does stuff
 if not (current_dialogue==nil) then
  for i,lin in ipairs(current_dialogue.lines) do
  	if i > max_lines or i * line_spacing > box_size-2 then break end
  	print(lin.str, px+lin.x, py+lin.y, 7)
  end
  if box_size == box_size_max then 
   print("🅾️",px+54,py+box_size_max-7,(t()%1)>0.5and 13or 6)
   	--	ik i couldve used pal() but i didn't feel like it sorry
   if #current_dialogue.lines>max_lines then spr((t()%1)>0.5and 63or 62,px+side_margin,py+box_size_max-11)end
  end
 end
end
-->8
-- effects

mem_pals={
		-- darkest
	'',
		-- almost darkest
	'0x0000.0000,0x0100.0000,',
		-- darker
	'0x0000.0000,0x0501.0000,0x0002.0100,0x1000.0000',
		-- dark
	'0x0000.0000,0x0d05.0001,0x0104.0201,0x1001.0101',
		-- mid dark
	'0x0101.0000,0x060d.0102,0x0309.0402,0x1002.050d',
	
		-- normal
	'0x0302.0100,0x0706.0504,0x0b0a.0908,0x100e.0d0c',	
		
		-- mid bright
	'0x0b04.0201,0x0707.0d09,0x0a07.0a0e,0x1007.0607',
		-- bright
	'0x0a04.0402,0x0707.060a,0x0707.0709,0x1007.0707',
		-- brighter
	'0x0709.0909,0x0707.0707,0x0707.070a,0x1007.0707',
		-- almost brightest
	'0x070a.0a0a,0x0707.0707,0x0707.0707,0x1007.0707',
		-- brightest
	'0x0707.0707',

}


	-- generate palette from array
function form_poke(ind,state,e)
	state=state or 0
	local p=split(mem_pals[ind])
	local e=e or p[1]
	poke4(state==0 and 0x5f00 or 0x5f10,
		p[1]or e,
		p[2]or e,
		p[3]or e,
		p[4]or e
	)
end
-->8
--special map stuff
door_open = 8
door_closed = 22

function open_door(mx, my)
	mset(mx, my, door_open)
	sfx(8)
end

function close_door(mx, my)
	mset(mx, my, door_closed)
	sfx(8)
end

function gatefunc(mx, my, ind)
 if has_keycard(ind_order_map[ind]) then
  add(current_sequences, create_gate_sequence(mx, my))
  if not ind == 8 then add_dscene(create_dscene("nice! only " .. keycards_left(), "more to go!")) end
	 last_checkpoint = {mx*8, my*8}
  if keycards_left() == 2 then add_dscene(create_dscene("i'm getting", "tired...")) end
  return true
 else
 	add_dscene(create_dscene("i need the", keycard_name_map[ind] .. " keycard", "before unlocking", "this gate!"))
 	return false
 end
end

function _init_interact_events()
	interact_events = {}
	--[[
	interact_events[145] = function(mx, my, ent, clicked)
	 if clicked and ent == ply then
		 if gatefunc(mx, my, 5) then
			 add_dscene(create_dscene("whuh...","did that gate...","just explode?!"))
			 add_dscene(create_dscene("apparently i","haven't been", "down here in", "a while..."))
			 --todo remove this
			 _real_game_keycards_init()
			end
	 end
	end --white gate
	--]]
	interact_events[22] = function(mx, my, ent, clicked)
	 mset(mx, my, 15)
	 sfx(8)
	 last_checkpoint = {ent.x, ent.y}
	end --door
	for gate,ind in pairs(keycard_tile_map) do
	 if not (ind == 5) then
			interact_events[gate] = function(mx,my,ent,clicked)
			 if clicked and (ent == ply) then
				 if gatefunc(mx, my, ind) and gate == 107 then
				 	add_dscene(create_dscene("whuh...","did that gate...","just explode?!"))
			   add_dscene(create_dscene("apparently i","haven't been", "down here in", "a while..."))
     end
		  end
			end
		end
	end --other gates
	boxfunc = function(mx, my, ent, clicked)
		if ent.attacking and ent.item and ent.item.name == "crowbar" then
			mset(mx,my,144)
			sfx(15)
		end
	end
	interact_events[16],interact_events[18] = boxfunc,boxfunc
	--todo these are the sprite numbers for male door female door and unmarked door
 interact_events[68],interact_events[69],interact_events[46]=
 open_regular_door,open_regular_door,open_regular_door
end

function open_regular_door(mx, my, ent, clicked)
	if ent == ply and clicked then
		mset(mx, my, 104) -- todo is sprite number correct?
		sfx(8)
	 last_checkpoint = {ent.x, ent.y}
	end
end

function get_point_ahead(ent, reach)
	local z = (ent.z + 0.25) % 1
	local zsin = (ent.z + 0.5) % 1
	local x = (deg90_cos[z]*reach + (ent.x + 4))
	local y = (deg90_cos[zsin]*reach + (ent.y + 4))
	return {x,y}
end

deg90_cos = {[0]=0, [0.125]=0.7, [0.25]=1, [0.375]=0.7,[0.5]=0,[0.625]=-0.7, [0.75]=-1, [0.875]=-0.7}

--call entity tile interactions.
-- an entity is 'interacting' with a tile when they are standing in front of it.
-- to check if the entity clicked the tile, use the 'clicked' parameter.
-- to set an event:
-- interact_events[map tile] = function(mx, my, ent, clicked) ... end
reach = 7
function fire_tile_interactions()
	for ent in all(ents) do
		 local xy = get_point_ahead(ent, reach)
			local mx = xy[1]\8
			local my = xy[2]\8
			add(points, {x, y, 11})--todo remove debug
			local func = interact_events[mget(mx, my)]
	  if func then func(mx, my, ent, btnp(🅾️)) end
	end
end
-->8
--putting this thing here because it's annoying to scroll through main

 -- draw with rotation
 -- boolean bob
function draw_rotation(ent, free)
 local z=ent.atk_rot_add and q(ent.atk_rot_add, 8) or q(ent.z, 8)
	if (ent.owner) and ent.owner.atk_rot_add then z = q(ent.owner.atk_rot_add, 8) end
	local x=ent.x
	local y=ent.y
	if free == true then y += obj_bob*3 end
	local sprs=ent.sprs
	if(z==0.000)spr(sprs[1],x,y,1,1,_,_)
	if(z==0.125)spr(sprs[2],x,y,1,1,_,_)
	if(z==0.250)spr(sprs[3],x,y,1,1,_,_)
	if(z==0.375)spr(sprs[4]or sprs[2],x,y,1,1,(not sprs[4]) and 1 or _,_)
	if(z==0.500)spr(sprs[1],x,y,1,1,1,1)
	if(z==0.625)spr(sprs[2],x,y,1,1,1,1)
	if(z==0.750)spr(sprs[3],x,y,1,1,1,1)
	if(z==0.875)spr(sprs[4]or sprs[2],x,y,1,1,sprs[4] and 1 or _,1)
end
-->8
-- tile palettes/functions - --
slime_tile = 111
tile_pals={}
tile_pals[80]=5
tile_pals[81]=1
tile_pals[82]=0
tile_pals[89]=0
tile_pals[87]=1
tile_pals[88]=5

--[[
	-- item pickup tutorial
tile_pals[254]=function(x,y,ent)
		-- intro
	if light==6 then
		if not intro then
			intro=true
			add_dscene(create_dscene("that about wraps","up my shift!","","","*cling*","","hey! my keys!","they fell in","a metal grate!","","now i need","to go downstairs","and get them!","","esdf - move","arrows - turn", "🅾️ - interact"))
			mset(x,y,0)
	
			-- crowbar tutorial
		elseif not pick_up_tut then
			pick_up_tut=true
			add_dscene(create_dscene("a crowbar!","(🅾️ - pick up)"))
			mset(x,y,0)
		end
	end
end
--]]

tile_pals[slime_tile] = function(x, y, ent)
 if ent == ply then damage_ent(ply, 0.7) end
end

	-- item tutorial
tile_pals[255]=function(x,y,ent)
	if ent.item then
			-- crowbar tutorial
		if not item_ev then
			item_ev=true
			add_dscene(create_dscene("i could push","those boxes...","but this is","much cooler!","sorry boxes!","","(esdf or ❎", "to swing)"))
			mset(x,y,0)
			return
		end
	end
end
	-- exit door carpet
tile_pals[253]=function(x,y,ent)
	exit_timer=exit_timer and exit_timer+1 or 0
	
		-- todo - add keys check
	if exit_timer%20==0then
		add_dscene(create_dscene("i need","my keys!"))
	end
end

-->8
--keycards + gates
keycard_name_map = {[5]="white", [6]="red", [7]="green", [8]="orange", [9]="blue"}
keycard_tile_map = {[91]=6, [107]=8, [108]=9, [106]=7, [145]=5}
ind_order_map = {[5]=1, [6]=1, [7]=2, [8]=3, [9]=4}

function create_gate_sequence(gate_x, gate_y)
	--first is the screen shake sequence
	--second is the explosion sequence
	sequence = {
	 {ticks=50, update=function(self)
	 	if self.ticks == 50 then
	 	 intensity = 3
	 	 sfx(13)
	 	 mset(gate_x, gate_y, 109)
	 	end
	 	self.ticks -= 1
	 end},
	 {particles={},gate_x=gate_x,gate_y=gate_y,ticks=70,update=function(self, gate_x, gate_y)
	   for particle in all(self.particles) do
	   	particle.x += cos(particle.dir)*3
	   	particle.y += sin(particle.dir)*3
    end
	   if self.ticks == 70 then
	    sfx(14)
	    intensity = 4
	   	for i=1,40 do
	   		add(self.particles, {size=(rnd()*3)+2, x=self.gate_x*8, y=self.gate_y*8, dir=rnd()})
					end
					mset(self.gate_x, self.gate_y, 0)
    end
    self.ticks -= 1
	 end,
	 draw=function(self)
	  for particle in all(self.particles) do
	  	circfill(particle.x, particle.y, particle.size, 10)
   end
	 end}
	}
	return sequence
end


function fill_collected()
	for i=1,#keycards_to_collect do
		keycards_collected[i] = false
	end
end

function _init_keycards()
	keycards_to_collect = {5} --indexes of keycard objs
	keycards_collected = {} --starts as {false}, when main game starts its {false, false, false, false}
	fill_collected()
	gate_unlocked = false
	--some internal info
	keycard_name_map = {[5]="white", [6]="red", [7]="green", [8]="orange", [9]="blue"}
 keycard_tile_map = {[91]=6, [107]=8, [108]=9, [106]=7, [145]=5}
 ind_order_map = {[5]=1, [6]=1, [7]=2, [8]=3, [9]=4}
end

function _real_game_keycards_init()
	keycards_to_collect = {6, 7, 8, 9}
	fill_collected()
	gate_unlocked = false
end

function keycards_left()
	local left = #keycards_collected
	for bool in all(keycards_collected) do
		if bool == true then left -= 1 end
	end
	return left
end

--ind: index of the keycard in the KEYCARD array!!
function collect(ind)
	for i=1,#keycards_to_collect do
		if keycards_to_collect[i] == ind then
			keycards_collected[i] = true
		end
	end
end

function has_keycard(ind)
	for i,bool in ipairs(keycards_collected) do
		if i == ind and bool == true then return true end
	end
	return false
end
-->8
--ui stuff

	-- update healthbar
function healthbar()
	local x,y,w,h
	=
	46+px,2+py,46+px,5+py
	
	rectfill(x-1,y-1,w+1+(5*ply.hp&-1),h+1,7)
	if(ply.dead)return
	rectfill(x,y,w+(5*ply.hp&-1),h,8)
end

card_spacing = 9
empty_keycard_spr = 102

function keycard_ui()
	for i=1,#keycards_to_collect do
		if keycards_collected[i] == true then
			spr(objects[keycards_to_collect[i]][1], px+1+card_spacing*(i-1), py+1)
	 else
	 	spr(empty_keycard_spr, px+1+card_spacing*(i-1), py+1)
  end
	end
end
-->8
--cutscenes
function pos_lerp(max_ticks, self, ent, startx, endx, starty, endy)
	local progress = (max_ticks-self.ticks) / max_ticks
	ent.x = (progress*(endx-startx)) + startx
	ent.y = (progress*(endy-starty)) + starty
end

function cam_lerp(max_ticks, self, startx, endx, starty, endy)
	local progress = (max_ticks-self.ticks) / max_ticks
	px = (progress*(endx-startx)) + startx
	py = (progress*(endy-starty)) + starty
end

--use strings (eg "4", "-5") for relative values
function lerp_anim(max_ticks, ent, endx, endy, camendx, camendy, draw, linit)
 return {max_ticks=max_ticks, update=function(self)
		if self.ticks == max_ticks then 
	  if linit then linit() end
	  if ent then
		  self.ipx = ent.x
	   self.ipy = ent.y
	  end
	  self.ipc_x = px
	  self.ipc_y = py
	  if type(endx) == "string" then endx = ent.x + endx end
	  if type(camendx) == "string" then 
	   if camendx == "reset" then camendx = ui_pos()[1]
	   else camendx = camendx + px end 
	  end
	  if type(endy) == "string" then endy = ent.y + endy end
	  if type(camendy) == "string" then
	   if camendy == "reset" then camendy = ui_pos()[2] 
	   else camendy = camendy + py end
	  end
	 end
	 --logs = {}
	 --add(logs, "start: " .. self.ipx .. ",".. self.ipy)
	 --add(logs, "end: " .. endx .. "," .. endy)
	 self.ticks -= 1
	 if camendx and camendy then
	 	cam_lerp(max_ticks, self, self.ipc_x, camendx, self.ipc_y, camendy)
  end
  if ent and endx and endy then
  	pos_lerp(max_ticks, self, ent, self.ipx, endx, self.ipy, endy)
  end
 end, draw=draw}
end

function dialogue_anim(dscene)
	return {max_ticks=1, update=function(self)
    if self.inited then 
     self.ticks = 0
     return
    end
    if self.ticks == 1 then
    	self.dialogue = true
    	add_dscene(dscene)
    	self.inited = true
    end
 end}
end

function zswitch(ent, z)
	return {max_ticks=1, update = function(self)
	 if type(z) == "string" then z = ent.z + z end
	 ent.z = z
	 self.ticks = 0
	end
	}
end

function wait(ticks)
	return {max_ticks=ticks, update = function(self)
	 self.ticks -= 1
	end}
end

function runit(func)
	return {max_ticks=1, update=function(self)
	 self.ticks -= 1
	 func()
	end}
end

c4_room_originx = 680
c4_room_originy = 64

--this is what happens when you provide 'self' for each animation and not the whole cutscene...
--beware, those allergic to global variables will perish
knife_pos1 = {c4_room_originx+46,c4_room_originy+12}
knife_pos2 = {knife_pos1[1]-1,knife_pos1[2]-5}
knife_pos3 = {knife_pos2[1] - 64, knife_pos2[2]}
knife = {x=knife_pos1[1],y=knife_pos1[2], z=0}
knife_sprite = 118
knife_sprite_rotated = 119
bag_ripped_spr = 115
bag_riptop_spr = 116
bag_ripbot_spr = 117
bag_pos = {c4_room_originx + 40, c4_room_originy+8}
bag_top = {x=bag_pos[1], y=bag_pos[2]}
c4_spr = 113
c4_wall = 114
c4_wall_pos = {c4_room_originx + 50, c4_room_originy+16}
display_c4 = 0
room2_entrance = {c4_room_originx + 64, c4_room_originy+16}
function _cutscenes_init()
 current_sequences = {}
 --c4
 c4_cutscene = {
  zswitch(ply, 0),
  lerp_anim(20, ply, c4_room_originx + 20, c4_room_originy + 20, c4_room_originx, c4_room_originy - 16),
  runit(function()mset(c4_room_originx\8, c4_room_originy\8+2, 19) sfx(8) end),
  dialogue_anim(create_dscene("*huff, puff*", "my legs...", "i don't think", "they can take", "it anymore.")),
  zswitch(ply, 0.125),
  wait(10),
  dialogue_anim(create_dscene("hey...", "someone left an", "emergency bag", "here!")),
  zswitch(ply, 0),
  wait(10),
  lerp_anim(15, ply, c4_room_originx + 40, "-3"),
  zswitch(ply, 0.25),
  wait(15),
  dialogue_anim(create_dscene("hmmm, no", "zipper...", "let's get", "slicin'!")),
  {ticks=30, update=function(self)
	  if self.ticks == 30 then
	  	sfx(10)
	  end
	  self.ticks -= 1
  end, draw=function(self)
   --draw knife
   spr((knife.z == 1) and knife_sprite_rotated or knife_sprite, knife.x, knife.y)
  end},
  lerp_anim(15, knife, knife_pos2[1], knife_pos2[2]),
  zswitch(knife, 1),
  wait(15),
  runit(function() 
   mset(bag_pos[1]\8, bag_pos[2]\8, bag_ripped_spr)
   sfx(16)
  end),
  lerp_anim(30, knife, knife_pos3[1], knife_pos3[2]),
  lerp_anim(25, bag_top, bag_top.x, bag_top.y - 64, nil, nil, function(self)
   spr(bag_riptop_spr, bag_top.x, bag_top.y)
   if display_c4 == 0 then
   	spr(c4_spr, bag_pos[1], bag_pos[2] + sin(t())*3)
   end
  end,
  function() --init
   mset(bag_pos[1]\8, bag_pos[2]\8, bag_ripbot_spr)
   sfx(17)
  end),
  wait(30),
  dialogue_anim(create_dscene("c4! perfect!", "i'll use it to", "blow up that", "locked door!")),
  wait(10),
  lerp_anim(13, ply, "0", "-2"),
  runit(function()
   sfx(2)
   display_c4 = 2
  end),
  lerp_anim(13, ply, "0", "2"),
  wait(10),
  zswitch(ply, 0),
  dialogue_anim(create_dscene("here goes", "nothing!")),
  lerp_anim(20,ply, "10", "0"),
  wait(5),
  lerp_anim(20, ply, "-16", "0", nil, nil, function()
   if display_c4 == 1 then spr(c4_wall, c4_wall_pos[1]-1, c4_wall_pos[2]) end
  end, function() sfx(13) display_c4 = 1 end),
  runit(function() sfx(18) end),
  wait(70),
  {particles={},ticks=70,update=function(self)
	   for particle in all(self.particles) do
	   	particle.x += cos(particle.dir)*3
	   	particle.y += sin(particle.dir)*3
    end
	   if self.ticks == 70 then
	    sfx(14)
	    intensity = 4
	   	for i=1,40 do
	   		add(self.particles, {size=(rnd()*3)+2, x=c4_wall_pos[1], y=c4_wall_pos[2], dir=rnd()})
					end
					mset(c4_room_originx\8 + 7, c4_room_originy\8 + 2, 0)
					display_c4 = 2
    end
    self.ticks -= 1
	 end,
	 draw=function(self)
	  for particle in all(self.particles) do
	  	circfill(particle.x, particle.y, particle.size, 10)
   end
	 end},
  dialogue_anim(create_dscene("hey look,", "i didn't even", "need a", "keycard to", "make that door", "explode!")),
  wait(5),
  runit(function() _init_br() end),
  lerp_anim(50, ply, room2_entrance[1], room2_entrance[2], room2_entrance[1]-8, room2_entrance[2]-32, nil, function()
   --lerp init todo: add fade in/out
   
  end),
  wait(15),
  lerp_anim(70, nil, nil, nil, "55", "-16"),
  wait(70),
  dialogue_anim(create_dscene("oh my...", "is this...", "the break room?!")),
  lerp_anim(70, nil, nil, nil, "-55", "16"),
  dialogue_anim(create_dscene("i'd better be", "sneaky...")),
  lerp_anim(20, nil, nil, nil, "reset", "reset")
 }
 --end cutscene
 end_cutscene = {
 	zswitch(ply, 0.75),
  wait(15),
 	lerp_anim(60, ply, end_tile[1]*8, end_tile[2]*8 + 8, "0", "25"),
 	dialogue_anim(create_dscene("i finally made", "it!", "now to", "find my", "key...")),
 	wait(60),
 	runit(function() gamefinished = true end)
 }
end

--cutscene sequence system

function update_sequence()
 local already_locked = false
 for sequence in all(current_sequences) do
  if not (already_locked and not sequence.async) then --cant have two lock cutscenes at once
	  if update_specific_sequence(sequence) then del(current_sequences, sequence)
	  else
	   if not sequence.async then already_locked = true end
	   if sequence.cam_override then camera_override = true end
	  end
  end
 end
 if already_locked then camera_override = true end
 return already_locked
end

function update_specific_sequence(current_sequence)
 local makenil = true
	for anim in all(current_sequence) do
		if anim.ticks > 0 then 
			if anim.dialogue then
				if not update_dialogue() then anim.dialogue = false end
			else
				anim.update(anim)
			end
			makenil = false
			break
	 end
	end
	if makenil and current_sequence.loop then
		for anim in all(current_sequence) do
			anim.ticks = anim.max_ticks
		end
		makenil = false
	end
	return makenil
end

function add_sequence(sequence)
  for anim in all(sequence) do
    if anim.max_ticks then
      anim.ticks = anim.max_ticks
	end
  end
  add(current_sequences, sequence)
end

function draw_sequence()
 for current_sequence in all(current_sequences) do
	for anim in all(current_sequence) do
	if (anim.dialogue == true) then
		draw_dialogue()
	end
		if anim.draw then anim.draw(anim) end
		if anim.ticks > 0 then break end
	end
 end
end
-->8
--location based functions
--loc: xy pair, tile location
--func: function that is called when the player walks on that location
loc_funcs = {}
bro = {94, 8}
function fire_loc_funcs()
 local mx = (ply.x+4)\8
 local my = (ply.y+4)\8
 for locfunc in all(loc_funcs) do
 	if (locfunc.loc[1] == mx and locfunc.loc[2] == my) then
 		locfunc.func(mx, my, locfunc)
		end
 end
end

cantc4cut = false
function trigger_c4cut(mx, my, self)
 if cantc4cut then return end
	ply.spd = 0
 add_sequence(c4_cutscene)
 del(loc_funcs, self)
 cantc4cut = true
end

--c4 cutscene^
end_tile = {94, 21} --tile right outside door to final room
loc_funcs[1] = {loc={86,10},func=trigger_c4cut}
add(loc_funcs, {loc={86,9}, func=trigger_c4cut})
add(loc_funcs, {loc={86, 11}, func=trigger_c4cut})
add(loc_funcs, {loc=end_tile, func=function(mx,my,self)
 ply.spd = 0
 del(loc_funcs, self)
 add_sequence(end_cutscene)
end})
--end cutscene^

function setdoor(mx, my)
 if current_door2 then current_door1 = {current_door2[1], current_door2[2]}
 else current_door1 = {0,0} end
	current_door2 = {mx, my}
end

function resetdoor()
	current_door1 = {0,0}
	current_door2 = {107, 7}
	current_set_de = nil
end

current_set_de = nil

function doorevent(trx, try, drx, dry)
	add(loc_funcs, {loc={trx, try}, func=function(self)
	 if current_set_de == self then return end
	 setdoor(drx, dry)
	 current_set_de = self
	end})
end

--set break room doors (todo ADJUST THESE LOCATIONS)

doorevent(bro[1]-1, bro[2]+2, bro[1]+13, bro[2]-1)
doorevent(bro[1]+14, bro[2]-1, bro[1]+29, bro[2])
doorevent(bro[1]+30, bro[2], bro[1]+30, bro[2]+5)
doorevent(bro[1] + 29, bro[2] + 5, bro[1] + 19, bro[2] + 14)

-->8
--break room sequences
--first left-pointing corner right above entrance, tile based, 'break room origin'
break_room = false
hro = {(bro[1] + 21)*8, (bro[2] + 8)*8}

function is_waiting(ent)
	for enemy in all(enemies_waiting) do
		if ent == enemy then return true end
	end
	return false
end

function _init_br()
 if current_door1 or current_door2 then unlock_doors() end
 resetdoor()
	break_room = true
	enemies_waiting = {}
	enemies_alerted = {}
	persist_enemies_left = 0
	add_br_sequences()
end

function unlock_doors()
	mset(current_door1[1], current_door1[2], 22)
	mset(current_door2[1], current_door2[2], 22)
	sfx(8)
end

function add_br_sequences()
	add_sequence(box_kick())
	add_sequence(spinny())
	add_sequence(dummy_sequence())
	add_sequence(card_table())
	add_sequence(kissing())
	add_sequence(beachball())
	add_sequence(hopscotch(0))
	add_sequence(hopscotch(24))
	add_sequence(wavey())
end

function alert_enemy(ent)
 del_watcher(ent)
	add(enemies_alerted, {ent=ent, ticks=20})
	sfx(19) -- alert sfx
	if persist_enemies_left == 0 then
		mset(current_door1[1], current_door1[2], 19)
		mset(current_door2[1], current_door2[2], 19)
	end
	sfx(8)
	ent.persist = true
end

function update_alerted()
 for watcher in all(enemies_alerted) do
  local ent = watcher.ent
	 ent.z = q(atan2(ply.x-ent.x, ply.y-ent.y), 8)
	 watcher.ticks -= 1
	 if watcher.ticks <= 0 then 
	  del(enemies_alerted, watcher)
	  ent.locked = false
	  --todo make enemy target player
	  ent.max_spd *= 1.2
	  ent.persist = true
	  persist_enemies_left += 1
	  ent.iframes = 15
	 end
	end
end

function draw_alerted()
 for watcher in all(enemies_alerted) do
  local ent = watcher.ent
	 print("!", ent.x+2, ent.y - 7, 8)
	end
end

function del_watcher(ent)
	for watcher in all(enemies_waiting) do
		if watcher.ent == ent then del(enemies_waiting, watcher)
		break end
	end
end

function get_watcher(ent)
	for watcher in all(enemies_waiting) do
		if watcher.ent == ent then return watcher end
	end
end

function realdist(x1,y1,x2,y2)
 if abs(x1 - x2) > 150 or abs(y1-y2) > 150 then return 1000 end
	return sqrt((x2-x1)^2 + (y2-y1)^2)
end


hopscotch_start = 6 + hro[1] - 5
hopscotch_increment = 6
hopscotch_times = 8

function br_alert_check()
 --add(logs, persist_enemies_remaining)
	for i,watcher in ipairs(enemies_waiting) do
	 local dist = realdist(ply.x, ply.y, watcher.ent.x+4, watcher.ent.y+4)
	 if dist == 0 or dist == 11.4414 or dist == 9.1227 then dist = 1000 end
		if dist <= watcher.radius then
		 del(current_sequences, watcher.sequence)
		 for ent in all(watcher.entities) do
		 	alert_enemy(ent)
   end
		end
	end
end
default_radius = 14

function reset_break_room()
 enemies_waiting = {}
 enemies_alerted = {}
	for seq in all(sequences) do
		if seq.br then del(sequences, seq) end
	end
	unlock_doors()
	resetdoor()
end

function break_roomify(sequence, entities)
 if entities then
 	for ent in all(entities) do
 	 if ent == nil then stop() end
 		ent.locked = true
 		ent.x,ent.y = ent.org_x,ent.org_y
 		add(msets, {ent.org_x\8, ent.org_y\8})
 		ent.hp = 1
 		if ent.dead then
 			ent.dead = false
			end
 		add(enemies_waiting, {ent=ent, radius=ent.alert_radius or default_radius, sequence=sequence, entities=entities})
		end
 end
 sequence.async = true
 sequence.loop = true
 sequence.br = true
 return sequence
end

function dummy_sequence()
	d_ents = {
		get_spawned_ent(bro[1] + 11, bro[2] + 2),
		get_spawned_ent(bro[1] + 12, bro[2] + 3),
		get_spawned_ent(bro[1] + 10, bro[2] + 3)
	}
	add_key = {{0, 1}, {-1, 0}, {1, 0}}
	z_key = {0.75, 0.5, 0}
	for i,ent in ipairs(d_ents) do 
	 ent.x += add_key[i][1] * -2
	 ent.y += add_key[i][2] * -2
	 ent.z = z_key[i]
	 ent.alert_radius = 17
	end
	seq = {}
	for i,ent in ipairs(d_ents) do
		local add_val = add_key[i]
		add(seq, lerp_anim(4, ent, add_val[1]*2 .. "", add_val[2]*2 .. ""))
		add(seq, lerp_anim(4, ent, (add_val[1] * -2) .. "", (add_val[2] * -2) .. ""))
	end
	return break_roomify(seq, d_ents)
	--[[return {{max_ticks = 50,update=function(self)
	 if self.ticks == 50 or self.ticks == 25 then
	 	cls(11)
	 	flip()
  end
  self.ticks -= 1
	end},loop=true,async=true}--]]
end

function spinny()
	local the_ent = get_spawned_ent(bro[1]+4, bro[2]-1)
	return break_roomify({runit(function() the_ent.z = (the_ent.z + 0.125)%1 end), wait(1)}, {the_ent})
end

function box_kick()
	local ent1 = get_spawned_ent(bro[1]+6, bro[2] + 3)
	ent1.z = 0.5
	local ent2 = get_spawned_ent(bro[1]+2, bro[2] + 3)
	local box = {x=bro[1]*8+10, y=bro[2]*8 + 24}
	local seq = {
	 lerp_anim(30, box, "14", "0", nil, nil, function(self) spr(18, box.x, box.y) end),
	 lerp_anim(2, ent2, "4", "0"),
	 lerp_anim(2, ent2, "-4", "0"),
	 lerp_anim(30, box, "14", "0"),
	 lerp_anim(2, ent1, "-4", "0"),
	 lerp_anim(2, ent1, "4", "0")
	}
	return break_roomify(seq, {ent1, ent2})
end

function card_table()
	local ents_here = {
	 get_spawned_ent(bro[1]+8, bro[2] - 2), 
	 get_spawned_ent(bro[1] + 10, bro[2] - 2)
	}
	ents_here[2].z = 0.5
	return break_roomify({wait(1)}, ents_here)
end

function kissing()
	local ents_here = {
	 get_spawned_ent(bro[1] + 17, bro[2]+1),
	 get_spawned_ent(bro[1]+18, bro[2] + 1)
	}
	ents_here[1].x += 1
	ents_here[2].x += 3
	ents_here[2].z = 0.5
	local seq = {
	 {max_ticks=50, update=function(self)
	    if self.ticks == 25 then
	    	ents_here[1].x += 1
	    	ents_here[2].x -= 1
     end
     self.ticks -= 1
     if self.ticks == 0 then 
      ents_here[1].x -= 1
      ents_here[2].x += 1
     end
	  end, draw=function(self)
	    if self.ticks < 25 then
	    	print("♥", ents_here[1].x + 5, ents_here[1].y - 4, 14)
     end
	  end
	 }
	}
	return break_roomify(seq, ents_here)
end

beach_ball_spr = 120

function beachball()
	local inv_ents = {
	 get_spawned_ent(bro[1] + 31, bro[2] + 5),
	 get_spawned_ent(bro[1] + 31, bro[2] + 9)
	}
	local beachball_pos = {(bro[1]+32)*8, (bro[1]+10)*8}
	local beachball_vel = {0.5, 0.5}
	local wall_left = (bro[1]+31)*8
	local wall_right = (bro[1] + 33)*8
	local seq = {{max_ticks = 1,
	 update=function(self)
	  x = (abs(((t()/2)%1)-0.5)*24) + (bro[1] + 31) * 8 - 3
	  y = (abs((((t()+0.3)/2)%1)-0.5)*32) + (bro[2]  + 6)*8
	  for ent in all(inv_ents) do
	   ent.x = x
	  end
	 end, draw=function(self) spr(beach_ball_spr,x, y) end}
	}
	return break_roomify(seq, inv_ents)
end

function hopscotch(y_off)
 local seq = {}
 local ents_here = nil
 if y_off > 0 then
 	ents_here = {
 	 get_spawned_ent(bro[1] + 21, bro[2] + 7),
 	 get_spawned_ent(bro[1] + 22, bro[2] + 7)
 	}
 	add(seq, wait(30))
 else ents_here = {
   get_spawned_ent(bro[1] + 23, bro[2] + 7),
   get_spawned_ent(bro[1] + 24, bro[2] + 7)
 } end
 local ent1_pos = {hro[1] - 9, hro[2] + y_off}
 local hop_entrance = {hro[1], hro[2]+y_off}
 for ent in all(ents_here) do ent.alert_radius = 14 end
 ents_here[1].x = ent1_pos[1]
 ents_here[1].y = ent1_pos[2] + 9
 ents_here[2].x = ent1_pos[1]
 ents_here[2].y = ent1_pos[2] - 9
 for i=1,2 do
  local return_pos_y = ent1_pos[2] + ((i == 1) and 9 or -9)
 	add(seq, lerp_anim(20, ents_here[i], hop_entrance[1], hop_entrance[2]))
 	add(seq, wait(15))
 	for j=1,6 do
 		add(seq, lerp_anim(15, ents_here[i], "6", "0"))
 		add(seq, wait(5))
		end
		add(seq, wait(5))
		add(seq, zswitch(ents_here[i], 0.75))
		add(seq, lerp_anim(20, ents_here[i], "0", return_pos_y))
		add(seq, wait(20))
		add(seq, zswitch(ents_here[i], 0.5))
		add(seq, wait(20))
 	add(seq, lerp_anim(50, ents_here[i], ent1_pos[1], return_pos_y))
 	add(seq, zswitch(ents_here[i], 0))
 	add(seq, wait(10))
 end
 return break_roomify(seq, ents_here)
end

function tc(t1,t2)
  for i=1,#t2 do
      t1[#t1+i] = t2[i]
  end
  return t1
end

function wavey()
	local origin = {105, 20}
	columns = {{}, {}, {}, {}}
	for i=0,3 do
		for j=0,1 do
			add(columns[i+1], get_spawned_ent(origin[1] + i, origin[2] + j))
		end
	end
	all_ents = {}
	for c in all(columns) do
		for ent in all(c) do
			add(all_ents, ent)
		end
	end
	seq = {max_ticks=1, update=function(self)
	 for i,c in ipairs(columns) do
	 	for ent in all(c) do
	 		ent.y += sin((t()+ 0.2*i)%1)*3
			end
  end
	end}
	all_wave_ents = all_ents
	return break_roomify(seq, all_ents)
end
__gfx__
00000000fff499d6ff9967ff67ff67ff00000000fff1333fff333ffff3fff3ff00000000fff56612ff6622ff22ff22ff00000000000000000000000000d77dff
00000000f249a967f4a9d6ffd6ffd69f00000000ff13bbb3f13bb3ff3b3f3b3f00000000f1567622f57612ff12ff126f000000000000000000000000006666ff
0070070024949fff4944ffff99ff9aa900000000f131333f13bb3fff3b3f3bb30000000015656fff5655ffff66ff67760000000000000000000000000676676f
0007700049ac4fff449c4f679a9449a90000000013bb1fff1111ff3f3b3113b300000000567c5fff556c5f22676556760000000000000000000000000000000f
0007700049ac496729aac4d6494cc4940000000013bb133f13bb13b3131bb13100000000567c56221677c512565cc566000000000000000000000000ffffffff
0070070024949ad6249a94a9f49aa94f00000000f1313bb313bb1bb3f13bb31f000000001565671215676576f567765f000000000000000000000000ffffffff
00000000f249aa9ff44949a9f249942f00000000ff13bb3f1333133fff1331ff00000000f156776ff5565676f156651f000000000000000000000000ffffffff
00000000fff499ffff22449fff2442ff00000000fff133fff11111fffff11fff00000000fff666ffff11556fff1551ff000000000000000000000000ffffffff
fffffffffff9afffffffffff00d88dfff00d2d86ffffff6600d77dffd666666d9999999f999999999999999f999999999999999999999999ffff9ff9ffff9fff
f2222ffffff90ffff222222f008228fff00dd966fffffd66007667ff60d0d0d6999999ff99999999999999ff9933bb99f999999999999999ff9ff9999f99ffff
f2442ffffff00ffff244442f002222fff00dad66ffffddb6006666ff6d0d0d069999999f999999999999999f933bb7b9f9f9999999999999fff99f99999f9f9f
02442222fff0afff0244442f0282282ff00ddd11fffdad660676676f60d0d0d699999f9f9999999999999f9f933bbbb99f999999999999999f999999999999ff
02222242fff9afff0222222f0282282ff00dd111fffdd8660676676f6d0d0d06999999f999999999999999f98333bb39ff99999999999999f9f99999999999f9
01100222fff90fff0111111f0282282ff00d1111f00d8866067cc76f60d0d0d6999999ff9999999999f99fff83333339f9f9f9999f99f999f999999999999f9f
01100111fff00fff0111111f002882fff0011111f00d8db6006776ff6d0d0d0699999f9f99999999999ff9ff88333399ffff99f999ff99f9ff9999999999999f
ffff0111fff0afffffffffff008dd8fff0011111f00dd966007dd7ff5666666d9999999f999999999ff9ffff99999999fff9fffffff9fffff999999999999999
f888886fff886ffff76fffffffffff24ffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000001111111100000000
8f888887f88887ff6886fffffffff24ffff7f6fff6ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000001dddddd100000000
fff88886888886ff8888fffff76f24fffff6ffff7ffffffff6fffffffffff86f1d666dffffffffffffddffffffffffff00000000000000001dddddd100000000
fff2286f88822fff8882222268824fffffff8ffff76fffff7ff8888fffff8fff1d666dfffffddfffff66fffffffddfff00000000000000001dddddd100000000
fff42fff8fff42ff888244448882ffffffff8ffffff8fffff76ffff6fff8ffffffffffffff66dfffff66fffffffd66ff00000000000000001dddddd100000000
fff42ffff8fff42f88ffffff8888ffffffff8fffffff8fffffffffffff6ffffffffffffffd66ffffff66ffffffff66df00000000000000001dddd1d100000000
fff42fffffffff428ffffffff888f8ffffff8ffffffff8ffffffffff6f7fffffffffffff1ddfffffffddfffffffffdd100000000000000001dddddd100000000
fff42ffffffffff4f8ffffffff888ffffff6fffffffff6fffffffffff7fffffffffffffff1ffffffff11ffffffffff1f00000000000000001dddddd100000000
fffddddddddddddddddddfff00d66dddddd66dff00d66dfffffddddddddddfff00d66dfffffddfffddd66ddddddddddd00d66dddddd66dffffffffffffffffff
ffd666666666666666666dff00d6666666666dff00d66dffffd6666666666dff00d66dffffd66dff666666666666666600d6666666666dffffffffffffffffff
ffd666666666666666666dff00d6666666666dff00d66dffffd6666666666dff001dd1fff0d66dff666666666666666600d6666666666dffffffffffffffffff
ff1dddddddddddddddddd1ff001dddddddddd1ff00d66dffffd66dddddd66dff001111ff00d66dffddddddddddd66ddd00d66dddddd66dffffffffffffffffff
f011111111111111111111ff00111111111111ff00d66dffffd66d1111d66dff001111ff00d66dff1111111111d66d1100d66d1111d66dffffffffffffffffff
0011111111111111111111ff00111111111111ff00d66dffffd66d1111d66dff001111ff00d66dff1111111111d66d1100d66d1111d66dfffff66ffffffddfff
0011111111111111111111ff00111111111111ff00d66dfff0d66d1111d66dff001111ff00d66dff1111111111d66d1100d66d1111d66dffff6666ffffddddff
f00111111111111111111ffff001111111111fff00d66dff00d66d1111d66dfff0011fff00d66dff1111111111d66d1100d66d1111d66dfff666666ffddddddf
ff6666fff6ffffff11111111f111111f1111111111111111f111111fffffffffff1111ffffffffdffffffff1ffffffff11111111ffffff6ffffffffff33b333f
f677776ff6ffffff16666661f111111f1dddddd11dddddd1f111111ffbbfff3ff111661ffaaaffdffffffff1f111111f11111111ffffff6fff3bbffffff33bff
67777776f6ffffff11111111fddddddf1dcdddd11dedddd1fddddddff3bffffff1dd561ffaaaffdffffffffd16d6d6d1ddddddddffffff6ffbbbbbfffff3bfff
d677776df67777ff9190aa10fd6688df1dddddd11dddddd1fd6666dfffff3bfff111111f0999ff1ffffffffd16d6d6d12269aa6dff77776ff3bbb3fffffb3fff
1d6666d1f67777ff11111111fd66bbdf1dcdddd11dedddd1fddddddffffbbbbff1dddd1f0607f777fffffffd16d6d6d12829aa6dff77776fff33fffffff3bfff
10dddd01067777ff1dddddd10d66ccdf1dcdd1d11dedd1d10d6666dffff3bb3ff111111fffff0666fff0000d16d6d6d17277777dff777760fffffbbffff3bbff
10000001016666ff1dddddd10ddddddf1dddddd11dddddd10d6666dfffff33fffffffffffffffffffff0000df111111fddddddddff666610f3fff3bfff3b33ff
1f0000f1010001ff1dddddd10100001f1dddddd11dddddd10ddddddffffffffffffffffffffffffffff00001ffffffff00010001ff100010ffffffff3333333f
66666666dddddddd5555555511111111005dd5ff001551ff000110ffffffffffffffffffffffffffffffffff1dddddd100d11dff7777777700d6777ffffff777
66666666dddddddd5555555511111111005dd5ff001551ff000110ffffffffffffffffffffffffffffffffffd111111d001111ff7777777700d6777ffffff777
dddddddd555555551111111100000000005dd5ff001551ff000110ffffffffffffffffffffffffffffffffffd111111d001ff1ff7777777700d6777ffffff777
dddddddd555555551111111100000000005dd5ff001551ff000110ffffffffffffffffffffffffffa00aa00a1dddddd1ffffffff666666d600d6777ffffff6d6
66666666dddddddd5555555511111111005dd5ff001551ff000110ffffffffffffffffffffffffff99009900d666666dffffffff6666666600d6777ffffff666
66666666dddddddd5555555511111111005dd5ff001551ff000110ffffffffffffffffffffffffffffffffffd66dd66dffffffffdddddd5d00d6777ff0000d5d
dddddddd555555551111111100000000005dd5ff001551ff000110ffffffffffffffffffffffffffffffffffddd88dddffffffffdddddddd00d6777ff0000ddd
dddddddd555555551111111100000000005dd5ff001551ff000110ffffffffffffffffffffffffffffffffffd66dd66dfffddfff0100001f00d6777ff0000010
fffd6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0000000000000001dddddd11dddddd11dddddd11dddddd11dddddd1000bbb00
ffd0f6fffff0f2fffff0f1fffff0f3fffff0f4fffff0f6fffff0ffffff22ffffd000000000000000d111111dd111111dd111111dd111111dd111111d0bb222b0
f677777fff00282fff001c1fff003b3fff00494fff00676fff000ffff2288fff1000000000000000d111111dd111111dd111111dd111111dd111111dbb2262b0
0677877ff0028882f001ccc1f003bbb3f0049994f0067776f00000ff02282fff10000000000000001dddddd11dddddd11dddddd11dddddd11dddddd1b226222b
0678887f0028282f001c1c1f003b3b3f0049494f0067676f00000fff002266ffd000000000000000d666666dd666666dd666666dd66aa66dd616116db222222b
0677877ff00282fff001c1fff003b3fff00494fff00676fff000fffff000676f1000000000000000d66dd66dd66dd66dd66dd66dd66aa66dd16dd16db222222b
0677777fff0f2fffff0f1fffff0f3fffff0f4fffff0f6fffff0ffffffff0066f1000000000000000dddbbdddddd99ddddddccddddaaaaaadddd00ddd0bb222b0
000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00ffd000000000000000d66dd66dd66dd66dd66dd66dd66aa66dd16dd61d000bbb00
fffffffff3fffffffffffffffffffffffffffffffffffffffffffffffffffffffff888ff00000000000000000000000000000000000000000000000000000000
fff6666f3f33f88fffffff08fff6666ffff6666fffffffffffffffffffffffffff88888f00000000000000000000000000000000000000000000000000000000
f66ffff636038068fffff068f66ffff6f66ffff6ffffffffffffffffffff44fff888eee900000000000000000000000000000000000000000000000000000000
f88f888f66366866ffff0083f88f888ff88f888fffffffffff7ffffffff74ffff88eeee900000000000000000000000000000000000000000000000000000000
8888888877777777ffff0d368888818888888f88ffffffffff77fffffff77ffff8eeee9900000000000000000000000000000000000000000000000000000000
88888888660dd066ffff0d3688811111888fffffffffffffff77fffffff77ffff77ee99f00000000000000000000000000000000000000000000000000000000
8888888877777777ffff0d63811181188fffffffffff8ff8ff74fffffff7ffffff7999ff00000000000000000000000000000000000000000000000000000000
f888888ff60dd06fffff0066f888888ffffffffff888888ffff4ffffffffffffffffffff00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000003313131343000000000000000000000000000000000000000000000000000000000000000000000000
0000000033131313131313131313b3c6b31343005300530000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000005300331313134300530000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000005300000000000000530000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000003313131313131313430000000000000000000000000000000000000000000000000000000000000000000000000000000000
2fffffff1dddddd1ffffffffffffffffaaafffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff4ff112d111111dfffff22ffffff22fafaaaaff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f4ff441fd111111dfffff22fffff2222aaafaaff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
fff144ff1dddddd1f222fffff22f2222ffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2f211fffd666666df2222ffff22ff22ffaaaffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff11412fd66dd66df2222ffffffffffffafaaaaf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f4f114ffddd77dddff22ff2ffff2fffffaaafaaf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff2ffff1d66dd66dffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777f0777777fffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777f0777777fffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777f0666666fffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777f0100ff1fffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777f0d00ffdfffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777f0d0000dff777777f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777ffffffffff777777f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777ffffffffff777777f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4e4e4344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e444304000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0f0ff0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f4ffff4f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffff
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffff
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffff
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffff
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028888882ffffffffffffffff
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000082211228ffffffffffffffff
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000082111128ffffffffffffffff
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028888882ffffffffffffffff
__label__
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555777777777777777777777777777777777777dd
555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555777777777777777777777777777777777777dd
55555555005555555555555555005555555555555555005555555555555555005555555555555555555555555577888888888888888888888888888888887766
55555555005555555555555555005555555555555555005555555555555555005555555555555555555555555577888888888888888888888888888888887766
55555500000055555555555500000055555555555500000055555555555500000055555555555555555555555577888888888888888888888888888888887766
55555500000055555555555500000055555555555500000055555555555500000055555555555555555555555577888888888888888888888888888888887766
555500000000005555555500000000005555555500000000005555555500000000005555555555555555555555778888888888888888888888888888888877dd
555500000000005555555500000000005555555500000000005555555500000000005555555555555555555555778888888888888888888888888888888877dd
55000000000055555555000000000055555555000000000055555555000000000055555555555555555555555577888888888888888888888888888888887711
55000000000055555555000000000055555555000000000055555555000000000055555555555555555555555577888888888888888888888888888888887711
55550000005555555555550000005555555555550000005555555555550000005555555555555555555555555577777777777777777777777777777777777711
55550000005555555555550000005555555555550000005555555555550000005555555555555555555555555577777777777777777777777777777777777711
5555550055555555555555550055555555555555550055555555555555550055555555555555555555555555555555555555555555555500dd6666dd11111111
5555550055555555555555550055555555555555550055555555555555550055555555555555555555555555555555555555555555555500dd6666dd11111111
5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555550000dd6666dd11111111
5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555550000dd6666dd11111111
55555555555555555555555555555555555555555555555555dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6666dd55555555
55555555555555555555555555555555555555555555555555dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6666dd55555555
555555555555555555555555555555555555555555555555dd66666666666666668866666666666666666666666666666666666666666666666666dd55555555
555555555555555555555555555555555555555555555555dd66666666666666668866666666666666666666666666666666666666666666666666dd55555555
555555555555555555555555555555555555555555555555dd66666666666666668866666666666666666666666666666666666666666666666666dd55555511
555555555555555555555555555555555555555555555555dd66666666666666668866666666666666666666666666666666666666666666666666dd55555511
555555555555555555555555555555555555555555555555dd6666dddddddddddd88dddddddddddddddddddddddddddddddddddddddddddddddddd1155551133
555555555555555555555555555555555555555555555555dd6666dddddddddddd88dddddddddddddddddddddddddddddddddddddddddddddddddd1155551133
555555555555555555555555555555555555555555555555dd6666dd111111111111111111111111111111111111111111111111111111111111111155551133
555555555555555555555555555555555555555555555555dd6666dd111111111111111111111111111111111111111111111111111111111111111155551133
555555555555555555555555555555555555555555555555dd6666dd111111111188111111111111111111111111111111111111111111111111111155555511
555555555555555555555555555555555555555555555555dd6666dd111111111188111111111111111111111111111111111111111111111111111155555511
555555555555555555555555555555555555555555555500dd6666dd111111111111111111111111111111111111111111111111111111111111111155555555
555555555555555555555555555555555555555555555500dd6666dd111111111111111111111111111111111111111111111111111111111111111155555555
555555555555555555555555555555555555555555550000dd6666dd111111111111111111111111111111111111111111111111111111111111115555555555
555555555555555555555555555555555555555555550000dd6666dd111111111111111111111111111111111111111111111111111111111111115555555555
555555555555555555555555555555555555555555550000dd6666dd555555555511115555555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555555555511115555555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555555551133331155555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555555551133331155555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd5555551133bbbb3311555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd5555551133bbbb3311555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd5555113311bbbb1133115555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd5555113311bbbb1133115555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555533bb33111133bb335555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555533bb33111133bb335555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555533bbbb335533bb335555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555533bbbb335533bb335555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd55555533bb335533bb335555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd55555533bb335533bb335555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555555553355555533555555555555555555555555555555555555555555555555555555
555555555555555555555555555555555555555555550000dd6666dd555555553355555533555555555555555555555555555555555555555555555555555555
dddddddddddddddddddddddddddddddddddddddddddddddddd6666dd555555555555555555555555555555555555555555555555555555555555555555555555
dddddddddddddddddddddddddddddddddddddddddddddddddd6666dd555555555555555555555555555555555555555555555555555555555555555555555555
666666666666666666666666666666666666666666666666666666dd555555555555555555555555555555555555555555555555555555555555555555555555
666666666666666666666666666666666666666666666666666666dd555555555555555555555555555555555555555555555555555555555555555555555555
666666666666666666666666666666666666666666666666666666dd555555555555555555555555555555555555555555555555555555555555555555555555
666666666666666666666666666666666666666666666666666666dd555555555555555555555555555555555555555555555555555555555555555555555555
dddddddddddddddddddddddddddddddddddddddddddddddddddddd11555555555555555555555555555555555555555555555555555555555555555555555555
dddddddddddddddddddddddddddddddddddddddddddddddddddddd11555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111155555555555555554499998888888888665555555555555555555555555555555555555555
11111111111111111111111111111111111111111111111111111155555555555555554499998888888888665555555555555555555555555555555555555555
555555555555555555555555555555555555555555555555555555555555555555224499aa886688888888887755555555555555555555555555555555555555
555555555555555555555555555555555555555555555555555555555555555555224499aa886688888888887755555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555552244994499555555888888886655555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555552244994499555555888888886655555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555554499aacc44555555222288665555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555554499aacc44555555222288665555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555554499aacc44996677442255555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555554499aacc44996677442255555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555552244994499aadd66442255555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555552244994499aadd66442255555555555555555555555555555555555555555555
555555555555555555555555555555555555555555555555555555555555555555224499aaaa9955442255555555555555555555555555555555555555555555
555555555555555555555555555555555555555555555555555555555555555555224499aaaa9955442255555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555554499995555442255555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555554499995555442255555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
dddddd55555555555555555555555555551133333355555555555555555555555555555555555555555555555555555533331155555555555555555555555555
dddddd55555555555555555555555555551133333355555555555555555555555555555555555555555555555555555533331155555555555555555555555555
666666dd5555555555555555555555551133bbbbbb335555555555555555555522222222222255555555555555555533bbbb3311555555555555555555555555
666666dd5555555555555555555555551133bbbbbb335555555555555555555522222222222255555555555555555533bbbb3311555555555555555555555555
666666dd55555555555555555555551133113333335555555555555555555555224444444422555555555555555533bbbb331133115555555555555555555555
666666dd55555555555555555555551133113333335555555555555555555555224444444422555555555555555533bbbb331133115555555555555555555555
dd6666dd555555555555555555551133bbbb1155555555555555555555555500224444444422555555555555555555333311bbbb331155555555555555555555
dd6666dd555555555555555555551133bbbb1155555555555555555555555500224444444422555555555555555555333311bbbb331155555555555555555555
dd6666dd555555555555555555551133bbbb1133335555555555555555555500222222222222555555555555555555555511bbbb331155555555555555555555
dd6666dd555555555555555555551133bbbb1133335555555555555555555500222222222222555555555555555555555511bbbb331155555555555555555555
dd6666dd555555555555555555555511331133bbbb33555555555555555555001111111111115555555555555555553333331133115555555555555555555555
dd6666dd555555555555555555555511331133bbbb33555555555555555555001111111111115555555555555555553333331133115555555555555555555555
dd6666dd5555555555555555555555551133bbbb335555555555555555555500111111111111555555555555555533bbbbbb3311555555555555555555555555
dd6666dd5555555555555555555555551133bbbb335555555555555555555500111111111111555555555555555533bbbbbb3311555555555555555555555555
dd6666dd555555555555555555555555551133335555555555555555555555555555555555555555555555555555553333331155555555555555555555555555
dd6666dd555555555555555555555555551133335555555555555555555555555555555555555555555555555555553333331155555555555555555555555555
dd6666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dd6666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dd666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
dd666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
dd666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
dd666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
11dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__gff__
0000000000000000000000000000000001000101010101000000000000000000000000000000000000000000000000000101010101010101010101010101000001000001000000000000000001000000000000000101010000000001000101010000000000000000000001010101010000000000000000000000000000000000
0000000000000000000000000000000000010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
00000000000000000000000000000000000000000000000000000000000000000000000000000036313b3131313131313736313735000000350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000003564380000004f4e00353505353500001035003631313131313131313131313b313131313131313700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0036313131313131313131313131313131313131313131313131313b3131313b3131313131313735050047363131371035354e3535005f5d3500356200050500000000000000160043004a4c00433331313700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00355f5d0005000000000000121000001000001200171717000093355f5d5d3500111210110035333131313400003512333400353512000035003331313131313131313131313d004705000005000000053500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00351000003631313700363131313131370036313131313131370035000000350036313137003536313131313137354e00001235355f5d5d3c3131313131313131313131313134000017171700003632003500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003592600035000035003500003631313400333131370000003500351000123500350000350035350000001210353331370036343500001216004f4700004f004e4f0000050500000017171700003500003500000000000000000000000000000000000000363131313131370000000000000000000000000000000000000000
0035129310350000350035000035939200050012933337000035003c3700363d0035000035003c34001717171535000035003500351000003c313137003631313131313131313700001717174e0035003637000000000000000000000000000000363131313405d0050000333131313131313700000000000000000000000000
0033313b313a31313400333131340036371736370015350000350033345a33341035000035001600001792171435003634003337355f5d5e350000354e35000500000000000035000047000000003500353500000000000000000000000000000035050000000000000000160000000000103331313131313131313b31313137
000000354e92004f0093000000001235351735350014350000350010120510000035000035003c370017171793350035000000353512105e353631340033313700000000000033313137003631313400353500000036313131313131373631313134000000000000000000363131370000000000000000000000001600000035
0000003500363131313131313137003334173334003634000033313131313131313400003500353512000000123500350017003535000000353510120000003c31313131313700000035003500004f473c343631313d000000007000333400000000000000000000000000350000350505000000000000000000003c37000035
0000003593350000000000000035001200000012103500000000000000000000000000003500353331375a363134003512001035350000103535000505000038490000002135000000350035003031313d0035000016000000000000130021000000000000000000000500350000333131313137121000003631313435000035
00000035473536313131370000333131375a363131340000000000003631313131313131340035000035003500000033370036343500000033340005004700000000000047350000003500350000000035003500363d000000000000363137000500000005000000050905350000000000000033313131313400000035000035
3631313a6a3a3d1200153500000000003500350000000000000000003512001717170000000035000035003331313131345a3331345f5d005e110000000000390000000000350500003500354e121005350035003533313137003631340033313131313131313131313131340000000000363131313131313131313134000035
35000047009216006014353631313131345a33313131313700000000355a36313131375a36313400003593001717170000009200000000125e1100600000003c31313200303a370000354e33313131313a3735003500000035003500000000000000000000000000000000000000000000350000002500000000006013050035
344e363131313d12001035351000000000000000000010350000000035003500000035003500000000333131313131313131313137005f5d101100000000003500000000004e35000035000047004f05003535003500000035413500363131313131313131313131313131313131313137350000000000003631313137000035
350035000000333131313435001717120000121017170035000000003500350000003500350000000000000000000000000000003500000036313131313131340036313137003500003c3131313b313131373500350000003d0035001300000000000000000000000000000000000000353500050505050035000000356f6f35
37003500000000000000003500171700000010121717003331313131345a33313131345a33313131313131313131313131313131345a5a5a350012000000120047354f00350035000035460005350047463535003331370035003500350000003631313131313131313131313131370035350000000000003500000035000035
3c6e3a3131313131313131340010120000000000000000119200000010009200001200000010100500121200120012051212001210125d5d336b370000000000003331313d0035000035211793350017003535000000350035003500350000003500000000000000000000000000350035350000000000003500000035050035
350000ff12100012000000110012100000000000120000110000121717170017171700171717121717171017171712171760121717170000000035000000000000000043350535000035920000354e0512353331370035003d003500350000003500000000000000363131313137350035350000000000003500000035000035
3500363131313131313131370000000012101000000000111012009300001012001005000012050010000005001212000012120500125f5d36313d00000000000000000035003331313a3131443a453131340000350035003c313400350000003500000000000000350000000035350035350000000000003500000033313134
350035000000000000000035001717001012100017170036313b3131313b31313131375a36313131313131313131313131313131375a5a5a3500350041404d00000000003500004e0000000000050000003500003500350000000000333b2e3b3400000000000000350505050535350035350000000000003500000000000000
35253500000000000000003500171700121012001717003500350000103500000000350035000000000000000000000000000000350000003500350000050000000000003500000000000000470041404d3500003500350000000036313494333137000000000000350505050533341033340000000000003500000000000000
35003500000000000000003512000000000000000000103500350017003500000000350035000000000000000000000000000000350017003500333131313b31320030313a313b313131313131313131313137003500350000000035949494949435000000000000350000000000000000160000000000003500000000000000
35003500000000000000003331313131375a36313131313400351000123500000000350035000000000000000000000000000000350017003500000000003543000000004a4c350005600017171743604a4c350035003500000000359417171794350000000000003331313131313131313a3131313131313400000000000000
3331340000000000000000000000000035103500000000000033375a363400363131345a3331313700000000003631313131313735001700350000000000350000000041404d3500a2000000a2000000a20016003500350000000035941717179435000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000035003536313131370000350035000035121000000000123500000000003512005f5d5d333400000035000000000035004e00000000003541a04d0041a04d0041a04d3c003500350000000035949494949435000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000363131345a3535000000333131345a3331313d101200000000103c31313131313d00171717001100001700350000000000350041404d0000473500a0470500a0000500a00035003500350000000033313131313134000000000000000000000000000000000000000000000000000000000000
000000000000000000000000003512100000353500210012001000171717001600000000000000160017171700160017171700110017170035000000000035003031313131313d41a14d0041a14d0041a14d35003500350000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000035003631313435000000363131313b3131313d000000000010123c31313131313d001717170011000000003500000000003500004f004e000035050000000005004e00000535003500350000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000003500333131313a31313134000000160012001612000000001210350000000000350000001012363131313134000000000033313131313137003541404d0041404d0041404d35053500350000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000035000012121000001012000017003c3131313a313131313131313400000000003331313131313400000000000000000000000000000000350038000000000000000000470035003500350000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000003331313131313131313137000000350000000000000000000000000000000000000000000000000000000000000000000000000000000035000000004e001717170000000035003500350000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
410f00200017300175001750017300175001750017300175001730017500175001730017500175001730017500173001750017500173001750017500173001750017300175001750017300175001750017300175
0101000011650136502d4512a451264512e451244512d451000002c45000000224500c450000001b4500000000000000000e650155500f600000000000010600276501f650155001165000000155000065513600
010700000765511255116551a2552865519605146550e6051d6052160500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
010700000e6550c151091510c6550010003100001000c6000f2000000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
31090000102510c2510c2510025100105001050010500105001050010500105001050010500105001050010500105001050010500105001050010500105001050010500000000000000000000000000000000000
00080000332552e6552f2552625527655182551b65508455000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000b00000d0430b700077031770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
150f00001755518555175551855517555000000c6050c605066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000326552f6502e6500000023650000001265012655066000000000000000000000000000000001c1002610030100381003c1003f1003f1003f1003f1003f1003f1003d1003d1003c1003a1003610030100
240f00002105421052210522105221052210522105221052230512305223052230522305223052230522305500204012040220403204002040120402204032040020401204022040320400204012040220403204
210f000009051200512d05134001000000c6550c65537000030010000101001020010300100001010010200103001000010100102001030010000101001020010300100001010010200103001000010100102001
300a00000007200071000000000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002
110f00000c55511555175551a5551d555245552655528550305513055230552305523055230552305523055521550235502155023550245552454524535245250050000500005000050000500000000000000000
0108000030653227732c500215001a500260003420018000000000000000000286002860026000342001800000000000000000028600286002600034200180000000000000000002860028600260003420000000
0005000015650156501665028650146502a650286502665018650296502a650396501a6503965039650396502065023650246502565036650356503465032650316501c650146500f6500a650036502600034200
000800000c655031530c6500865501655001530000001600000000000000000106002f6000000000000000000000000000000000000025600000000000000000000000000000000000002860000000266002f600
000300000d65012650176501865023650236501000006650000000000000000046500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
590f0000241522d1523215237152371523715237152371532400029000240002b0002400024000240002400000100390003c0003c00039000390053c000380003900538000390053900539005390053900500000
000800003004524000240002400024000300550000500005000050000530055000050000500005000053005500005000053006500005000053007500005300750000530075000053007530075300753007530075
290d00001d5521a552205521150000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
__music__
01 09494344
01 0a494344
01 090b4344
01 0a0c4344

