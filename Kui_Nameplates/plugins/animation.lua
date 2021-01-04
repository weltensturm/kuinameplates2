-- provide status bar animations
local addon = KuiNameplates
local kui = LibStub('Kui-1.0')
local mod = addon:NewPlugin('BarAnimation')

local anims = {}

local min,max,abs,pairs = math.min,math.max,math.abs,pairs
local GetFramerate = GetFramerate
-- local functions #############################################################
-- cutaway #####################################################################
do
    local tick_frame, smoothing, num_smoothing = nil,{},0

    local function Tick()
        local limit = 30/GetFramerate()
        for bar, _ in pairs(smoothing) do
            bar.KuiFader.speed = (bar.KuiFader.speed or 0) + limit*4
            bar.KuiFader.width = bar.KuiFader.width or 0
            bar.KuiFader.width = math.max(0, bar.KuiFader.width - select(2, bar:GetMinMaxValues())*limit/1000.0*bar.KuiFader.speed)
            if bar.KuiFader.width < 0.5 then
                bar.KuiFader.speed = 0
            end
            bar.KuiFader:SetPoint(
                'RIGHT', bar, 'LEFT',
                ((bar:GetValue() + bar.KuiFader.width) / select(2, bar:GetMinMaxValues())) * bar:GetWidth(), 0
            )
        end
    end

    local function SetValueCutaway(self, value)
        if not self.KuiFader.width then
            self.KuiFader.width = 0
        else
            self.KuiFader.width = self.KuiFader.width + (self:GetValue() - value)
            tick_frame:Show()
            self.KuiFader:Show()
        end
        self:orig_anim_SetValue(value)
    end

    local function SetStatusBarColor(self,...)
        self:orig_anim_SetStatusBarColor(...)
        self.KuiFader:SetVertexColor(1,1,1)
    end

    local function SetAnimationCutaway(bar)
        if not tick_frame then
            tick_frame = CreateFrame('Frame')
            tick_frame:SetScript('OnUpdate', Tick)
        end

        local fader = bar:CreateTexture(nil,'ARTWORK')
        fader:SetTexture('interface/buttons/white8x8')

        fader:SetPoint('TOP')
        fader:SetPoint('BOTTOM')
        fader:SetPoint('LEFT',bar:GetStatusBarTexture(),'RIGHT')

        smoothing[bar] = true

        bar.orig_anim_SetValue = bar.SetValue
        bar.SetValue = SetValueCutaway

        bar.orig_anim_SetStatusBarColor = bar.SetStatusBarColor
        bar.SetStatusBarColor = SetStatusBarColor

        bar.KuiFader = fader
    end

    local function ClearAnimationCutaway(bar)
        if not bar.KuiFader then return end
        bar.KuiFader.width = 0
    end

    local function DisableAnimationCutaway(bar)
        ClearAnimationCutaway(bar)

        bar.SetValue = bar.orig_anim_SetValue
        bar.orig_anim_SetValue = nil

        bar.SetStatusBarColor = bar.orig_anim_SetStatusBarColor
        bar.orig_anim_SetStatusBarColor = nil

        smoothing[bar] = nil
        bar.KuiFader = nil
    end

    anims['cutaway'] = {
        set   = SetAnimationCutaway,
        clear = ClearAnimationCutaway,
        disable = DisableAnimationCutaway
    }
end
-- smooth ######################################################################
do
    local smoother,smoothing,num_smoothing = nil,{},0

    local function SmoothBar(bar,val)
        if not smoothing[bar] then
            num_smoothing = num_smoothing + 1
        end

        smoothing[bar] = val
        smoother:Show()
    end
    local function ClearBar(bar)
        if smoothing[bar] then
            num_smoothing = num_smoothing - 1
            smoothing[bar] = nil
        end

        if num_smoothing <= 0 then
            num_smoothing = 0
            smoother:Hide()
        end
    end

    local function SetValueSmooth(self,value)
        if not self:IsVisible() then
            self:orig_anim_SetValue(value)
            return
        end

        if value == self:GetValue() then
            ClearBar(self)
            self:orig_anim_SetValue(value)
        else
            SmoothBar(self,value)
        end
    end
    local function SmootherOnUpdate()
        local limit = 30/GetFramerate()
        for bar,value in pairs(smoothing) do
            local cur = bar:GetValue()
            local new = cur + min((value-cur)/3, max(value-cur, limit))

            if cur == value or abs(new-value) < .005 then
                bar:orig_anim_SetValue(value)
                ClearBar(bar)
            else
                bar:orig_anim_SetValue(new)
            end
        end
    end
    local function SetAnimationSmooth(bar)
        if not smoother then
            smoother = CreateFrame('Frame')
            smoother:Hide()
            smoother:SetScript('OnUpdate',SmootherOnUpdate)
        end

        bar.orig_anim_SetValue = bar.SetValue
        bar.SetValue = SetValueSmooth
    end
    local function ClearAnimationSmooth(bar)
        if smoother and smoothing[bar] then
            ClearBar(bar)
        end
    end
    local function DisableAnimationSmooth(bar)
        ClearAnimationSmooth(bar)

        bar.SetValue = bar.orig_anim_SetValue
        bar.orig_anim_SetValue = nil
    end
    anims['smooth'] = {
        set   = SetAnimationSmooth,
        clear = ClearAnimationSmooth,
        disable = DisableAnimationSmooth
    }
end
-- prototype additions #########################################################
function addon.Nameplate.SetBarAnimation(f,bar,anim_id)
    if not bar then return end
    f = f.parent

    if bar.animation and anims[bar.animation] then
        -- disable current animation
        anims[bar.animation].disable(bar)
    end

    if anim_id and anims[anim_id] then
        anims[anim_id].set(bar)
    else
        -- no animation; remove from animated bars
        if f.animated_bars and #f.animated_bars > 0 then
            for i,a_bar in ipairs(f.animated_bars) do
                if bar == a_bar then
                    tremove(f.animated_bars,i)
                end
            end
        end

        return
    end

    if not f.animated_bars then
        f.animated_bars = {}
    end

    if not bar.animation then
        tinsert(f.animated_bars, bar)
    end

    bar.animation = anim_id
end
-- messages ####################################################################
function mod:Hide(f)
    -- clear animations
    if type(f.animated_bars) == 'table' then
        for _,bar in ipairs(f.animated_bars) do
            anims[bar.animation].clear(bar)
        end
    end
end
-- register ####################################################################
function mod:OnEnable()
    self:RegisterMessage('Hide')
end
