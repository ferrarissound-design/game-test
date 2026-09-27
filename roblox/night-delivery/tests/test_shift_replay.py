"""Run: python -m pip install lupa tree-sitter tree-sitter-luau
Then: python -m unittest discover -s tests -v

Executes the shared rules and actual server functions with small Roblox mocks.
Luau compound assignments are lowered for Lua; UI/engine behavior still needs Studio.
"""
from pathlib import Path
import json
import unittest

from lupa import LuaRuntime
from tree_sitter import Language, Parser
import tree_sitter_luau

ROOT = Path(__file__).resolve().parents[1]
PARSER = Parser(Language(tree_sitter_luau.language()))


def source(path):
    return (ROOT / path).read_text()


def lower_updates(text):
    data = text.encode()
    edits = []

    def visit(node):
        if node.type == "update_statement":
            left, op, right = node.children
            lhs = data[left.start_byte:left.end_byte]
            rhs = data[right.start_byte:right.end_byte]
            operator = data[op.start_byte:op.end_byte][:-1]
            edits.append((node.start_byte, node.end_byte, lhs + b" = " + lhs + b" " + operator + b" (" + rhs + b")"))
        for child in node.children:
            visit(child)

    visit(PARSER.parse(data).root_node)
    for start, end, replacement in sorted(edits, reverse=True):
        data = data[:start] + replacement + data[end:]
    return data.decode()


class ShiftReplayTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.rules = self.lua.execute(source("src/ReplicatedStorage/NightDeliveryShiftRules.lua"))
        self.lua.globals().TEST_RULES = self.rules
        self.replay = self.lua.execute(lower_updates(source("src/ReplicatedStorage/NightDeliveryReplayRules.lua")))
        self.lua.globals().TEST_REPLAY = self.replay
        self.lua.globals().TEST_MODIFIERS = self.lua.execute(source("src/ServerScriptService/NightDeliveryCargoModifiers.lua"))

    def test_all_luau_syntax_and_rojo_mapping(self):
        for path in (ROOT / "src").rglob("*.lua"):
            self.assertFalse(PARSER.parse(path.read_bytes()).root_node.has_error, str(path))
        project = json.loads(source("default.project.json"))
        mapped = project["tree"]["ReplicatedStorage"]["NightDeliveryShiftRules"]["$path"]
        self.assertTrue((ROOT / mapped).is_file())
        replay_path = project["tree"]["ReplicatedStorage"]["NightDeliveryReplayRules"]["$path"]
        self.assertTrue((ROOT / replay_path).is_file())

    def test_airborne_episode_and_respawn_do_not_refill_protection(self):
        order = self.lua.table_from({"equipmentId": "cushion"})
        self.rules.observeAirborne(order, True)  # Jumping
        self.rules.observeAirborne(order, True)  # Freefall, same jump
        self.assertTrue(order.cushionUsed)
        self.assertFalse(bool(order.jumpDamaged))
        self.rules.observeAirborne(order, False)  # Landing / grounded new character
        self.rules.observeAirborne(order, True)
        self.assertTrue(order.jumpDamaged)
        unprotected = self.lua.table_from({"equipmentId": "thermal"})
        self.rules.observeAirborne(unprotected, True)
        self.assertTrue(unprotected.jumpDamaged)

    def test_records_first_previous_best_and_invalid_legacy_data(self):
        clean = self.rules.cleanRecord(None)
        first, comparison = self.rules.completeRecord(clean, 3, 240)
        self.assertFalse(comparison.hasPrevious)
        second, comparison = self.rules.completeRecord(first, 4, 270)
        self.assertEqual(comparison.perfectDelta, 1)
        self.assertEqual(comparison.secondsSaved, -30)
        self.assertTrue(comparison.newPerfectBest)
        self.assertFalse(comparison.newTimeBest)
        self.assertEqual(second.bestSeconds, 240)
        third, comparison = self.rules.completeRecord(second, 2, 200)
        self.assertEqual(comparison.perfectDelta, -2)  # previous, not personal best
        self.assertEqual(third.bestPerfect, 4)
        self.assertEqual(third.count, 3)
        self.assertTrue(comparison.newTimeBest)
        self.assertEqual(self.rules.cleanRecord(self.lua.table_from({"count": float("nan")})).count, 0)
        self.assertEqual(self.rules.cleanRecord("legacy malformed value").count, 0)

    def grading_api(self):
        text = source("src/ServerScriptService/NightDeliveryPolish.server.lua")
        text = text[text.index("local JOB_LIMITS"):text.index("local function initializePlayer")]
        text = text.replace('require(script.Parent:WaitForChild("NightDeliveryCargoModifiers"))', 'TEST_MODIFIERS')
        text = text.replace('require(ReplicatedStorage:WaitForChild("NightDeliveryShiftRules"))', 'TEST_RULES')
        text = text.replace('require(ReplicatedStorage:WaitForChild("NightDeliveryReplayRules"))', 'TEST_REPLAY')
        prelude = '''
local RunService = {IsStudio = function() return false end}
local WORLD_NAME = 'NightDeliveryWorld'
local workspace = {FindFirstChild=function() return {GetAttribute=function(_, key)
    return key=='ThemeId' and 'japanese' or '日本住宅街'
end} end, NightDeliveryWorld={GetAttribute=function(_, key)
    return key=='ThemeId' and 'japanese' or '日本住宅街'
end}}
local sent = {}
local deliveryEvent = {FireClient = function(_, player, action, payload)
    table.insert(sent, {action=action, payload=payload})
end}
local clock = 100
local os = {clock = function() return clock end}
'''
        expose = '''
return {
    success=modifierSucceeded,
    modifier=findModifier,
    finish=finishTrackedOrder,
    track=trackNightShift,
    sent=sent,
    clock=function(n) clock=n end,
    put=function(player, state) playerState[player]=state end,
    fixture=function(equipmentId, cargoId, phase, elapsed)
        local attrs={NightShiftActive=true, NightShiftNumber=1, NightShiftPhase=phase,
            NightShiftEquipment=equipmentId, NightDeliveryCompletedJobSerial=1,
            NightShiftLastDeliverySerial=1, NightDeliveryLastRewardSerial=1,
            NightDeliveryLastRewardBase=200, NightShiftCoinsEarned=200}
        local coins={Value=200}
        local deliveries={Value=1}
        local stats={FindFirstChild=function(_, name) return name=='Coins' and coins or deliveries end}
        local p={GetAttribute=function(_, key) return attrs[key] end,
            SetAttribute=function(_, key, value) attrs[key]=value end,
            FindFirstChild=function() return stats end}
        local modifier=findModifier(cargoId)
        local order={baselineDeliveries=0, startedAt=clock-elapsed, timeLimit=60, jobSerial=1,
            jobTypeId='standard', modifier=modifier, equipmentId=equipmentId,
            publicModifier={title=modifier.title}, jumpDamaged=false}
        local state={activeOrder=order, sessionDeliveries=0, completedMissions={}}
        playerState[p]=state
        return p, coins, state, attrs
    end,
}
'''
        return self.lua.execute(lower_updates(prelude + text + expose))

    def test_quality_boundaries_and_unaffected_cargo(self):
        api = self.grading_api()
        for equipment, cargo, limit in [("thermal", "hot", 40), ("thermal", "frozen", 45), ("cushion", "hot", 30), ("cushion", "frozen", 35)]:
            order = self.lua.table_from({"equipmentId": equipment})
            self.assertTrue(api.success(api.modifier(cargo), "A", limit, order))
            self.assertFalse(api.success(api.modifier(cargo), "A", limit + 0.001, order))
        for equipment, expected in [("checklist", True), ("thermal", False), ("cushion", False)]:
            self.assertEqual(api.success(api.modifier("premium"), "B", 45, self.lua.table_from({"equipmentId": equipment})), expected)
        for cargo in ["none", "oversized", "secret", "mystery", "tip"]:
            for grade in ["S", "A", "B", "C"]:
                baseline = api.success(api.modifier(cargo), grade, 40, self.lua.table_from({"equipmentId": "unknown"}))
                for equipment in ["thermal", "cushion", "checklist"]:
                    self.assertEqual(api.success(api.modifier(cargo), grade, 40, self.lua.table_from({"equipmentId": equipment})), baseline)

    def test_final_run_bonus_has_one_owner_and_duplicates_are_ignored(self):
        api = self.grading_api()
        p, coins, state, attrs = api.fixture("checklist", "premium", "FinalRun", 45)
        api.finish(p)
        # B grade 25 + premium 140 + floor((core 200 + 25 + 140) * .5) = 347.
        self.assertEqual(coins.Value, 547)
        self.assertEqual(state.sessionDeliveries, 1)
        self.assertEqual(attrs.NightShiftRecordCount, None)  # no record for a partial night
        api.finish(p)
        self.assertEqual(coins.Value, 547)
        self.assertEqual(state.sessionDeliveries, 1)

    def test_frozen_penalty_and_bonus_use_the_same_equipment_limit(self):
        for elapsed, expected_grade, expected_bonus in [(40, "A", 100), (45.001, "C", 0)]:
            api = self.grading_api()
            p, _, _, _ = api.fixture("thermal", "frozen", "EarlyNight", elapsed)
            api.finish(p)
            result = api.sent[len(api.sent)].payload
            self.assertEqual(result.grade, expected_grade)
            self.assertEqual(result.modifierBonus, expected_bonus)

    def test_only_six_completed_deliveries_update_record_once(self):
        api = self.grading_api()
        p, _, _, attrs = api.fixture("thermal", "none", "EarlyNight", 20)
        for serial in range(1, 7):
            attrs.NightShiftLastDeliverySerial = serial
            api.track(p, "S", 20, 0)
            if serial < 6:
                self.assertEqual(attrs.NightShiftRecordCount, None)
        self.assertFalse(attrs.NightShiftActive)
        self.assertTrue(attrs.NightShiftResultPending)
        self.assertEqual(attrs.NightShiftRecordCount, 1)
        self.assertTrue(attrs.ThemeCompleted_japanese)
        self.assertEqual(attrs.NightShiftLastSeconds, 120)
        self.assertEqual(attrs.NightShiftBestPerfect, 6)
        api.track(p, "S", 20, 0)
        self.assertEqual(attrs.NightShiftRecordCount, 1)

    def test_replay_legacy_data_rank_cap_and_idempotent_collections(self):
        self.assertEqual(self.replay.rank(0)[0], 1)
        self.assertEqual(self.replay.rank(2)[1].name, "夜勤見習い")
        self.assertEqual(self.replay.rank(2)[1].reward, "自転車アクセント：ブルー")
        self.assertEqual(self.replay.rank(5)[1].reward, "自転車アクセント：アンバー")
        self.assertEqual(self.replay.rank(12)[1].reward, "自転車アクセント：ゴールド")
        self.assertEqual(self.replay.rank(999999)[1].name, "NIGHT COURIER")
        themes = self.replay.markTheme(None, "japanese", False)
        self.assertTrue(themes.japanese.visited)
        self.assertFalse(themes.japanese.completed)
        themes = self.replay.markTheme(themes, "japanese", True)
        themes = self.replay.markTheme(themes, "japanese", False)
        self.assertTrue(themes.japanese.completed)
        self.assertEqual(self.replay.completedCount(themes), 1)
        self.assertEqual(self.replay.completedCount(self.replay.markTheme(themes, "forged", True)), 1)
        found = self.replay.markOddity(None, "silent_house")
        found = self.replay.markOddity(found, "silent_house")
        found = self.replay.markOddity(found, "forged")
        self.assertTrue(found.silent_house)
        self.assertIsNone(found.forged)

    def test_return_to_depot_rejects_partial_or_active_state(self):
        text = source("src/ServerScriptService/NightDelivery.server.lua")
        body = text.split('\telseif action == "AcknowledgeNightShift" then', 1)[1].split('\telseif action == "AcceptSideJob"', 1)[0]
        api = self.lua.execute('''
local playerJobs, playerJobOffers = {}, {}
local cf = setmetatable({}, {__mul=function() return {} end})
local jobCounterRef = {CFrame=cf}
local JOB_COUNTER_INTERACTION_RANGE = 14
local SHIFT_TARGET = 6
local SHIFT_RULES = {DefaultEquipment='thermal'}
local CFrame = {new=function() return cf end}
local function requirePlayerReady(p) return p.ready end
local function fixture()
    local a={NightShiftActive=false, NightShiftResultPending=true, NightShiftDeliveries=6,
        NightShiftPhase='FinalRun', NightShiftEquipment='checklist'}
    local c={FindFirstChild=function(_, name) return name=='HumanoidRootPart' and {} or nil end,
        FindFirstChildOfClass=function() return {Health=100} end,
        PivotTo=function(self) self.returned=true end}
    local p={attrs=a, Character=c, ready=true}
    function p:GetAttribute(k) return self.attrs[k] end
    function p:SetAttribute(k, v) self.attrs[k]=v end
    return p
end
local function ack(player)
''' + body + '''
end
return {fixture=fixture, ack=ack, jobs=playerJobs, offers=playerJobOffers}
''')
        p = api.fixture()
        p.attrs.NightShiftActive = True
        api.ack(p)
        self.assertFalse(bool(p.Character.returned))
        p.attrs.NightShiftActive = False
        p.attrs.NightShiftDeliveries = 5
        api.ack(p)
        self.assertFalse(bool(p.Character.returned))
        p.attrs.NightShiftDeliveries = 6
        api.jobs[p] = self.lua.table_from({})
        api.ack(p)
        self.assertFalse(bool(p.Character.returned))
        api.jobs[p] = None
        p.attrs.NightDeliveryNextStopPending = True
        api.ack(p)
        self.assertFalse(bool(p.Character.returned))
        p.attrs.NightDeliveryNextStopPending = False
        p.attrs.JobOffersActive = True
        api.ack(p)
        self.assertFalse(bool(p.Character.returned))
        p.attrs.JobOffersActive = False
        api.ack(p)
        self.assertTrue(p.Character.returned)
        self.assertEqual(p.attrs.NightShiftPhase, 'EarlyNight')
        self.assertEqual(p.attrs.NightShiftDeliveries, 0)
        self.assertEqual(p.attrs.NightShiftEquipment, 'thermal')
        self.assertFalse(bool(p.attrs.NightShiftResultPending))
        p.Character.returned = False
        api.ack(p)
        self.assertFalse(bool(p.Character.returned))

    def test_rank_change_recolors_existing_bike_without_replacing_style(self):
        text = source("src/ServerScriptService/NightDelivery.server.lua")
        snippet = text[text.index("local BIKE_ACCENT_PARTS = {"):text.index("local function addBikeVisual(player)")]
        api = self.lua.execute('''
local REPLAY = TEST_REPLAY
local Color3 = {fromRGB=function(r,g,b) return r..','..g..','..b end}
''' + snippet + '''
return {refresh=refreshBikeAccent, color=courierAccentColor}
''')
        accent = self.lua.table_from({"Name": "Handlebar", "Color": "old"})
        frame = self.lua.table_from({"Name": "FrameTopTube", "Color": "purchased-style"})
        for part in [accent, frame]:
            part.IsA = lambda *args: args[-1] == "BasePart"
        visual = self.lua.table_from({"GetDescendants": lambda _: self.lua.table_from([accent, frame])})
        character = self.lua.table_from({"marker": "original character", "FindFirstChild": lambda _, name: visual if name == "DeliveryBikeVisual" else None})
        attrs = {"ShiftWins": 1, "BikeActive": True, "BikeStyleLevel": 3}
        player = self.lua.table_from({"Character": character, "GetAttribute": lambda _, key: attrs.get(key)})
        api.refresh(player)
        attrs["ShiftWins"] = 2
        api.refresh(player)
        self.assertEqual(accent.Color, "139,203,238")
        self.assertEqual(frame.Color, "purchased-style")
        self.assertEqual(player.Character.marker, "original character")
        self.assertTrue(attrs["BikeActive"])
        player.Character = None
        api.refresh(player)

    def test_acceptance_validation_and_equipment_lock(self):
        text = source("src/ServerScriptService/NightDelivery.server.lua")
        body = text.split('\telseif action == "AcceptJobOffer" then', 1)[1].split('\telseif action == "AcknowledgeNightShift" then', 1)[0]
        self.lua.execute('''
SHIFT_RULES=TEST_RULES
playerJobs={}; playerJobOffers={}; jobCounterRef={}; JOB_COUNTER_INTERACTION_RANGE=14
function requirePlayerReady(p) return p.ready end
function isNearPart(p) return p.near end
function isHouseUnlocked() return true end
housesFolder={FindFirstChild=function() return {} end}
function sendStatus(p, action) p.rejection=action end
function clearJobOffers(p) playerJobOffers[p]=nil end
function confirmJob(p) p.accepted=(p.accepted or 0)+1; playerJobs[p]={}; p.attrs.NightShiftActive=true end
function fixture(active)
    local p={ready=true,near=true,attrs={NightShiftActive=active,NightShiftEquipment='thermal'}}
    function p:GetAttribute(key) return self.attrs[key] end
    function p:SetAttribute(key,value) self.attrs[key]=value end
    playerJobOffers[p]={offers={{id='valid',houseName='YellowHouse'}}}
    return p
end
''')
        accept = self.lua.execute("return function(player, payload)\n" + body + "\nend")
        payload = self.lua.table_from({"offerId": "valid", "equipmentId": "cushion"})
        p = self.lua.globals().fixture(False)
        accept(p, payload)
        self.assertEqual(p.attrs.NightShiftEquipment, "cushion")
        accept(p, payload)
        self.assertEqual(p.accepted, 1)
        p = self.lua.globals().fixture(True)
        accept(p, payload)
        self.assertEqual(p.accepted, None)
        self.assertEqual(p.attrs.NightShiftEquipment, "thermal")
        for invalid in ["equipment", "offer", "distance", "pending", "loading"]:
            p = self.lua.globals().fixture(False)
            data = {"offerId": "valid", "equipmentId": "cushion"}
            if invalid == "equipment": data["equipmentId"] = "hacked"
            if invalid == "offer": data["offerId"] = "stale"
            if invalid == "distance": p.near = False
            if invalid == "pending": p.attrs.NightShiftResultPending = True
            if invalid == "loading": p.ready = False
            accept(p, self.lua.table_from(data))
            self.assertEqual(p.accepted, None, invalid)
            self.assertEqual(p.attrs.NightShiftEquipment, "thermal", invalid)

    def test_completed_night_does_not_leak_final_run_into_next_offers(self):
        text = source("src/ServerScriptService/NightDelivery.server.lua")
        function = text[text.index("local function shiftPhase"):text.index("local function shiftChance")]
        api = self.lua.execute('''
local studio = false
local RunService = {IsStudio=function() return studio end}
local attributes = {}
local world = {GetAttribute=function(_, key) return attributes[key] end}
local SHIFT_TARGET_DELIVERIES = 6
''' + function + '''
return {phase=shiftPhase, attributes=attributes, studio=function(value) studio=value end}
''')
        player = self.lua.eval("function(active, count) return {GetAttribute=function(_, key) if key=='NightShiftActive' then return active else return count end end} end")
        self.assertEqual(api.phase(player(False, 6)), "EarlyNight")
        self.assertEqual(api.phase(player(True, 5)), "FinalRun")
        self.assertEqual(api.phase(player(True, 2)), "MidNight")
        api.studio(True)
        api.attributes.QAForceNightPhase = "FinalRun"
        self.assertEqual(api.phase(player(False, 6)), "FinalRun")

    def test_record_survives_attribute_and_save_round_trip(self):
        record, _ = self.rules.completeRecord(None, 4, 180)
        new_player = self.lua.eval('''function()
            local attributes={}
            return {GetAttribute=function(_, key) return attributes[key] end,
                SetAttribute=function(_, key, value) attributes[key]=value end}
        end''')
        player = new_player()
        self.rules.writeRecord(player, record)
        saved = self.rules.readRecord(player)
        rejoined = new_player()
        self.rules.writeRecord(rejoined, self.rules.cleanRecord(saved))
        loaded = self.rules.readRecord(rejoined)
        next_record, comparison = self.rules.completeRecord(loaded, 5, 200)
        self.assertEqual(comparison.perfectDelta, 1)
        self.assertEqual(next_record.bestSeconds, 180)
        self.assertEqual(next_record.count, 2)


if __name__ == "__main__":
    unittest.main()
