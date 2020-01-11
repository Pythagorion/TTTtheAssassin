-- Let the Server load all the Stuff we need to get the Script running--
if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/VGUI/ttt/icon_the_assassin.vmt")

	util.PrecacheSound("CredoMotto.wav")
	util.PrecacheSound("eaglescream.wav")
	util.PrecacheSound("SoundsOfCreed/escapingTheACBOOHOOD.ogg")
	util.PrecacheSound("SoundsOfCreed/TiTofACIII.ogg")
	util.PrecacheSound("SoundsOfCreed/WoundedEagleACREVATIS.ogg")
	util.PrecacheSound("SoundsOfCreed/RunShayRunACRGUE.ogg")
	util.PrecacheSound("SoundsOfCreed/tPursuitACREVATIS.ogg")
	util.PrecacheSound("SoundsOfCreed/VeniceRooftopsACII.ogg")
	util.PrecacheSound("SoundsOfCreed/LettChaseBeginACREVATIS.ogg")
	util.PrecacheSound("SoundsOfCreed/HunterACRGUE.ogg")
	util.PrecacheSound("SoundsOfCreed/ChasetTargetACREVATIS.ogg")
	util.PrecacheSound("SoundsOfCreed/LaboredLostACREVATIS.ogg")

	util.AddNetworkString("AssassinsCreedoMessage")
	util.AddNetworkString("ACMUSIC")
	util.AddNetworkString("CreedOverrideTargetID")
	util.AddNetworkString("ACPMessage")
	util.AddNetworkString("ACTMessage")
	util.AddNetworkString("ACPassAwayMessage")
	util.AddNetworkString("ACPUninitiatedMessage")
	util.AddNetworkString("ACPSuccessMessage")
	util.AddNetworkString("ACPRevivalMessage")
	util.AddNetworkString("ACPGetRevivalMessage")
	util.AddNetworkString("ACPTimeLeftMessage")
	util.AddNetworkString("ACDisappearMessage")

	function CreedBroadcast(...)
		local acmsg = {...}

		net.Start("AssassinsCreedoMessage")
		net.WriteTable(acmsg)
		net.Broadcast()
	end
end

if CLIENT then
	net.Receive("CreedOverrideTargetID", function()
		hook.Add("HUDDrawTargetID", "CreedOverrideTargetID", function()
			local trace = LocalPlayer():GetEyeTrace(MASK_SHOT)
			local ent = trace.Entity

			if IsValid(ent) and IsPlayer(ent) and ent:GetNWBool("CreedDisguise") then
				return false
			end
		end)
	end)
end

-- The Setup for the ConVars the Users can use to configurate the Addon--
local CreedThemeActive = CreateConVar(
	"ttt_creed_soundtrack",
	1,
	{FCVAR_SERVER_CAN_EXECUTE, FCAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED},
	"Shall the Music be active?"
)
local CreedMottoActive = CreateConVar(
	"ttt_creed_motto",
	1,
	{FCVAR_SERVER_CAN_EXECUTE, FCAR_CLIENTCMD_CAN_EXECUTE,FCVAR_ARCHIVE, FCVAR_REPLICATED},
	"Shall the Assassin´s Motto be active?"
)
local CreedEagleScreamActive = CreateConVar(
	"ttt_creed_eagle_scream",
	1,
	{FCVAR_SERVER_CAN_EXECUTE, FCAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED},
	"Shall the Eagle scream after Finishing the Contract?"
)
local CreedRevivalFActive = CreateConVar(
	"ttt_creed_revival_feature",
	1,
	{FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED},
	"Is it possible to revive a Traitor when the Assassin completed the Contract?"
)

-- Here we configurate the Sounds we need later--
local LoadedSounds = {}

local function ReadSound(FileName)
	local sound, filter

	if SERVER then
		filter = RecipientFilter()
		filter:AddAllPlayers()
	end

	if SERVER or not LoadedSounds[FileName] then
		sound = CreateSound(game.GetWorld(), FileName, filter)

		if sound then
			sound:SetSoundLevel(0)

			if CLIENT then
				LoadedSounds[FileName] = {sound, filter}
			end
		end
	else
		sound = LoadedSounds[FileName][1]
		filter = LoadedSounds[FileName][2]
	end

	if sound then
		if CLIENT then
			sound:Stop()
		end

		sound:Play()
	end

	return sound
end

--The Server should know where it can find the Music--
local ACOST = {
	"SoundsOfCreed/TiTofACIII.ogg",
	"SoundsOfCreed/WoundedEagleACREVATIS.ogg",
	"SoundsOfCreed/RunShayRunACRGUE.ogg",
	"SoundsOfCreed/tPursuitACREVATIS.ogg",
	"SoundsOfCreed/VeniceRooftopsACII.ogg",
	"SoundsOfCreed/LettChaseBeginACREVATIS.ogg",
	"SoundsOfCreed/HunterACRGUE.ogg",
	"SoundsOfCreed/ChasetTargetACREVATIS.ogg",
	"SoundsOfCreed/escapingTheACBOOHOOD.ogg",
	"SoundsOfCreed/LaboredLostACREVATIS.ogg",
}

--Here is the Stuff for the Item and the Shop--
ITEM.hud = Material("VGUI/ttt/perks/hud_kredo_ttt2.png")
ITEM.EquipMenuData = {
	type = "item_passive",
	name = "Creed´s Contract",
	desc = "Nothing is true, Everything is permitted. \nYou´ve got 150 Seconds to kill your Target. \nOtherwise you´ll be revealed as a Traitor. \nIf a Traitor Colleague helps you, you both get revealed.",
}

ITEM.credits = 1
ITEM.material = "VGUI/ttt/icon_the_assassin"
ITEM.CanBuy = {ROLE_TRAITOR}
ITEM.corpseDesc = "He was a Brother of the Creed."
ITEM.TeamLimited = true
ITEM.GlobalLimited = true


--And now we tell the Server what to do, when the Item has been bought--
if SERVER then
	possible_targets_pool = {}
	possible_targets = {}

	--When a Traitor buys the Item, the first Values will be set and all players are informed--
	function ITEM:Bought(buyer)
		buyer:SetHealth(400)
		buyer:SetWalkSpeed(375)
		buyer:SetJumpPower(400)
		buyer.ACRevivalOption = false
		buyer:Give("weapon_ttt_knife")
		buyer:SetNWBool("CreedDisguise", true)
		net.Start("CreedOverrideTargetID")
		net.Broadcast()

		CreedBroadcast("Anonymous Creed: ", Color(153, 0, 0), "An Assassin is among us. Searching for Templars!")

		for _, q in pairs(player.GetAll()) do
			if ( CreedMottoActive:GetBool() ) then
			q:EmitSound("CredoMotto.wav")
			end
		end

		--First we create a Pool with all possible Targets--
		local function CreateTemplarPool(buyer)
			local creed_targets = {}
			local creed_detes = {}

			if not IsValid(buyer) or not buyer:IsActive() or not buyer:Alive() or buyer.IsGhost and buyer:IsGhost() or buyer:GetTeam() ~= TEAM_TRAITOR then
				return creed_targets
			end

			for _, buyers in ipairs(player.GetAll()) do
				if buyers:Alive() and buyers:IsActive() and not buyers:IsInTeam(buyer) and (not buyers.IsGhost or not buyers:IsGhost()) and (not JESTER or not buyers:IsRole(ROLE_JESTER)) then
					if buyers:IsRole(ROLE_DETECTIVE) then
						creed_detes[#creed_detes + 1] = buyers
					elseif buyers:GetTeam() == buyer:GetTeam() or buyers:GetSubRole() == ROLE_SPY or buyers:GetRole() == ROLE_PIRATE or buyers:GetRole() == ROLE_BODYGUARD then
						return
					else
						creed_targets[#creed_targets + 1] = buyers
					end
				end
			end

			if #creed_targets < 1 then
				creed_targets = creed_detes
			end

			return creed_targets
		end

		--We need a Table with all T-Colleagues of the Assassin--
		local tcolleagues = {}
			for _, tbuyers in pairs(player.GetAll()) do
				if tbuyers ~= buyer and tbuyers:GetTeam() == TEAM_TRAITOR then
					table.insert( tcolleagues, tbuyers )
				end
			end

		--And another one for a Message, including the Assassin--
		local traitorteam = {}
			for _, traitorsbuyers in pairs(player.GetAll()) do
				if traitorsbuyers:GetTeam() == TEAM_TRAITOR then
					table.insert( traitorteam, traitorsbuyers )
				end
			end

		--And another one without any traitors at all--
		local notrbuyers = {}
			for _, innobuyers in pairs(player.GetAll()) do
				if innobuyers:GetTeam() ~= TEAM_TRAITOR then
					table.insert( notrbuyers, innobuyers )
				end
			end	

		--We gather all spawns to use them soon--
		local spawnpointofmap = {}

					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_start"))
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_deathmatch"))
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_combine"))
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_rebel"))

					-- CS Maps
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_counterterrorist"))
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_terrorist"))

					-- DOD Maps
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_axis"))
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("info_player_allies"))

					-- (Old) GMod Maps
					spawnpointofmap = table.Add(spawnpointofmap, ents.FindByClass("gmod_player_start"))
		
		-- Setting up the Revival-Option for the Team_Traitor--
		hook.Add("TTT2PostPlayerDeath", "RevivalOfAC", function(ply)
			if buyer.ACRevivalOption then
				if ply:GetTeam() == TEAM_TRAITOR then 
					net.Start("ACPRevivalMessage")
					net.Send( ply )
					ply:Revive(10)
					timer.Simple(10.1, function()
						ply:SetPos(spawnpointofmap[math.random(1, #spawnpointofmap)]:GetPos()) 
					end)
					hook.Remove("TTT2PostPlayerDeath", "RevivalOfAC")
				end
			end	
		end)

		--We start a timer, so that the Assassin can prepare themselves. Then they get the Target and the Clock starts ticking--
		timer.Simple(5, function()	
			if CreedThemeActive:GetBool() and buyer:Alive() then
				creed_ostplays = true
				creed_sound = ReadSound(ACOST[math.random(1, #ACOST)])
				creed_sound:Play()
			end

			local creed_targets = CreateTemplarPool(buyer)
			local ChosenTemplar

			if #creed_targets > 0 then
				ChosenTemplar = creed_targets[math.random(1, #creed_targets)]
			end
				net.Start("ACPMessage")
				net.WriteEntity( ChosenTemplar )
				net.Send( buyer )

				net.Start("ACTMessage")
				net.WriteEntity( ChosenTemplar )
			 	net.Send( tcolleagues )

			--This Hook controls everything. When the contract is done, the Assassin gets his reward. When he was supported, he will fail.-- 
			hook.Add("PlayerDeath", "TemplarDeath", function(victim, inflictor, attacker)
				if ( victim == ChosenTemplar ) and ( attacker == buyer ) then

					if CreedRevivalFActive:GetBool() then
						buyer.ACRevivalOption = true
					end

					buyer:GodEnable()
					buyer:SetHealth(220)
					buyer:SetWalkSpeed(250)
					buyer:SetJumpPower(200)
					net.Start("ACPSuccessMessage")
				 	net.WriteEntity( ChosenTemplar )
					net.Send( buyer )
					buyer:SetNWBool("CreedDisguise", false)
					timer.Simple(4, function()
						if ( CreedRevivalFActive:GetBool() ) then
							net.Start("ACPGetRevivalMessage")
							net.Send( traitorteam )
						end	
					end)

					if ( CreedThemeActive:GetBool() ) then
						creed_sound:Stop()
					end

					if ( CreedEagleScreamActive:GetBool() ) then
						buyer:EmitSound("eaglescream.wav")
					end

					for _, g in pairs(player.GetAll()) do
						if not g:HasEquipmentItem("item_ttt_the_assassin") then
							g:ScreenFade( SCREENFADE.OUT, Color(255, 255, 255), 0.1, 4)
						end
					end

					buyer:SetPos(spawnpointofmap[math.random(1, #spawnpointofmap)]:GetPos())

					net.Start("ACDisappearMessage")
					net.Send( notrbuyers )

					hook.Remove("PlayerDeath" ,"TemplarDeath")

				elseif victim == ChosenTemplar and attacker:GetTeam() == TEAM_TRAITOR and attacker ~= buyer then
					CreedBroadcast("Anonymous Creed: ", Color(153, 0, 0), "The treacherous Assassin ", Color(255, 255, 000), buyer:Nick(), Color(153, 0, 0), " was support by a Traitor called ", Color(255, 255, 000), attacker:Nick(), Color(153, 0, 0), ". You can kill them!")

					buyer:SetWalkSpeed(250)
					buyer:SetJumpPower(200)
					buyer:SetHealth(100)
					buyer:SetNWBool("CreedDisguise", false)

					hook.Remove("PlayerDeath" ,"TemplarDeath")

					if CreedThemeActive:GetBool() then
						creed_sound:Stop()
					end

				elseif victim == ChosenTemplar and attacker ~= buyer and not attacker:GetTeam() == TEAM_TRAITOR and not attacker:IsWorld() and victim ~= attacker then
					if buyer:HasEquipmentItem("item_ttt_the_assassin") then
						net.Start("ACPUninitiatedMessage")
						net.WriteEntity( ChosenTemplar )
						net.Send( buyer )
					end

					buyer:SetWalkSpeed(250)
					buyer:SetJumpPower(200)
					buyer:SetHealth(180)
					buyer:SetNWBool("CreedDisguise", false)

					hook.Remove("PlayerDeath" ,"TemplarDeath")

					if CreedThemeActive:GetBool() then
						creed_sound:Stop()
					end

				elseif victim == ChosenTemplar and victim == attacker or attacker:IsWorld() then
					net.Start("ACPassAwayMessage")
					net.WriteEntity( ChosenTemplar )
					net.Send( buyer )

					buyer:SetWalkSpeed(250)
					buyer:SetJumpPower(200)
					buyer:SetHealth(180)
					buyer:SetNWBool("CreedDisguise", false)

					hook.Remove("PlayerDeath" ,"TemplarDeath")

					if CreedThemeActive:GetBool() then
						creed_sound:Stop()
					end
				else
					return
				end
			end)

			--The Assassin gets a notification that his time runs out soon
			timer.Simple(120, function()
				if ChosenTemplar:Alive() then
					net.Start("ACPTimeLeftMessage")
					net.Send( buyer )
				end
			end)

			--The Assassin fails. He gets revealed and he loses his advantages--
			timer.Create("ClockIsTicking", 150, 1, function()
				if ChosenTemplar:Alive() then
					CreedBroadcast("Anonymous Creed: ", Color(153, 0, 0), "The Assassin ", Color(255, 255, 000), buyer:Nick(), Color(153, 0, 0), " has failed. You can kill him. He isn´t one of us anymore!")

					buyer:SetWalkSpeed(250)
					buyer:SetJumpPower(200)
					buyer:SetHealth(100)
					buyer:SetNWBool("CreedDisguise", false)

					hook.Remove("PlayerDeath" ,"TemplarDeath")

					if CreedThemeActive:GetBool() then
						creed_sound:Stop()
					end
				end
			end)

			--When the Assassin dies, the Timer and Hook above shall be removed--
			hook.Add("PlayerDeath", "AssassinDies", function( victim, inflictor, attacker )
				if victim == buyer then
					timer.Remove("ClockIsTicking")

					hook.Remove("PlayerDeath" ,"TemplarDeath")
					buyer:SetWalkSpeed(250)
					buyer:SetJumpPower(200)
					buyer:SetHealth(100)
					buyer:SetNWBool("CreedDisguise", false)

					if CreedThemeActive:GetBool() then
						creed_sound:Stop()
					end
				end
			end) 	
		end)
	end

	function ITEM:RESET(buyer)
		hook.Remove("PlayerDeath" ,"TemplarDeath")
		hook.Remove("PlayerDeath","AssassinDies")
		if CreedRevivalFActive:GetBool() then	
			hook.Remove("PlayerDeath", "RevivalOfAC")
		end
		buyer.ACRevivalOption = false	
		timer.Remove("ClockIsTicking")
		timer.Remove("LetACrespawn")
		for _, j in pairs(player.GetAll()) do
			if j:HasEquipmentItem("item_ttt_the_assassin") then
				j:SetHealth(100)
				j:SetWalkSpeed(250)
				j:SetJumpPower(200)
				j:SetNWBool("CreedDisguise", false)
			end
		end	
	end

	hook.Add("TTTPrepareRound", "ResettAll", function()
		for _, j in pairs(player.GetAll()) do
			if j:HasEquipmentItem("item_ttt_the_assassin") then
				j:SetHealth(100)
				j:SetWalkSpeed(250)
				j:SetJumpPower(200)
				j:SetNWBool("CreedDisguise", false)
			end
		end	
	end)

	--These Hooks ensure that you can see that the dead Assassin was one--
	hook.Add("TTTBodySearchEquipment", "CreedoCorpseIcon", function(search, eq)
		search.theassassin = util.BitSet(eq, EQUIP_THE_ASSASSIN)
	end)

	hook.Add("TTTBodySearchPopulate", "CreedoCorpseIcon", function(search, raw)
		if not raw.eq_theassassin then return end

		local highest = 0
		for _, v in pairs(search) do
			highest = math.max(highest, v.p)
		end

		search.eq_theassassin = {img = "vgui/ttt/icon_the_assassin", text = "He was a Brother of the Creed.", p = highest + 1}
	end)
end


--The Client shall be able to get the Script´s Messages and the Music--
if CLIENT then
	net.Receive("AssassinsCreedoMessage", function(len)
		local acmsg = net.ReadTable()
		chat.AddText(unpack(acmsg))
	end)

	net.Receive("ACMUSIC", function(len)
		local Music = net.ReadString()
		local buyer = LocalPlayer()

		buyer.Music = CreateSound(buyer, Music .. ".ogg")
		buyer.Music:Play()
	end)

	net.Receive("ACPMessage", function()
		local ChosenTemplar = net.ReadEntity()
		chat.AddText("Anonymous Creed: ", Color(255,165,0), "Hey, young Novice. Your Target is: ", Color(148, 000, 211), ChosenTemplar:Nick(), Color(255,165,0), ". Eliminate him and you´ll be good to go. But do it alone!")
		chat.PlaySound()
	end)

	net.Receive("ACTMessage", function()
		local ChosenTemplar = net.ReadEntity()
		chat.AddText("Anonymous Creed: ", Color(100, 149, 237), "The Assassin´s Target is: ", Color(060, 179, 113), ChosenTemplar:Nick(), Color(100, 149, 237), ". DO NOT KILL HIM! If you help the Assassin to kill the Target, you both get revealed!")
		chat.PlaySound()
	end)

	net.Receive("ACPUninitiatedMessage", function()
		chat.AddText("Anonymous Creed: ", Color(255,165,0), "An Uninitiated killed your Target. You cannot fulfill your duty. Your Contract ends. We´ll give some Bonuses.")
		chat.PlaySound()
  	end)

  	net.Receive("ACPSuccessMessage", function()
  		chat.AddText("Anonymous Creed: ", Color(255,165,0), "Well done, young Novice. Welcome to the Brotherhood.")
  		chat.PlaySound()
  	end)

  	net.Receive("ACPassAwayMessage", function()
  		chat.AddText("Anonymous Creed: ", Color(255,165,0), "The Templar passed away by himself. You cannot fulfill your duty. Your Contract ends. We´ll give some Bonuses.")
  		chat.PlaySound()
  	end)

  	net.Receive("ACPRevivalMessage", function()
  		chat.AddText("Anonymous Creed: ", Color(255,165,0), "We got you covered. You won´t die today. You´ll be revived in 10 Seconds at a random spawnpoint of the map.")
  		chat.PlaySound()
    end)

    net.Receive("ACPGetRevivalMessage", function()
    	chat.AddText("Anonymous Creed: ", Color(100, 149, 237), "The Assassin fulfilled his duty. As a reward for his success, we will help your Team. If any of you die, we´ll bring you back to life!")
    	chat.PlaySound()
	end)
	
	net.Receive("ACPTimeLeftMessage", function()
		chat.AddText("Anonymous Creed: ", Color(255,165,0), "Hurry Up! The Target is still alive & you have only 30 seconds left to kill him!")
		chat.PlaySound()
	end)

	net.Receive("ACDisappearMessage", function()
		chat.AddText("Anonymous Creed: ", Color(255, 114, 86), "The Assassin disappeared. There´s no trace of him. He fulfilled his contract. The Game goes on!")
		chat.PlaySound()
	end)
end
