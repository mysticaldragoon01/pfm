include("film_clip")
include("time_frame.lua")

util.register_class("sfm.FilmClip",sfm.BaseElement)

sfm.BaseElement.RegisterAttribute(sfm.FilmClip,"mapname","")
sfm.BaseElement.RegisterArray(sfm.FilmClip,"trackGroups",sfm.TrackGroup)
sfm.BaseElement.RegisterArray(sfm.FilmClip,"animationSets",sfm.AnimationSet)
sfm.BaseElement.RegisterProperty(sfm.FilmClip,"subClipTrackGroup",sfm.SubClipTrackGroup)
sfm.BaseElement.RegisterProperty(sfm.FilmClip,"camera",sfm.Camera)
sfm.BaseElement.RegisterProperty(sfm.FilmClip,"timeFrame",sfm.TimeFrame)

function sfm.FilmClip:__init()
  sfm.BaseElement.__init(self,sfm.FilmClip)
end

function sfm.FilmClip:GetType() return "DmeFilmClip" end

function sfm.FilmClip:ToPFMFilmClip(pfmFilmClip)
  self:GetTimeFrame():ToPFMTimeFrame(pfmFilmClip:GetTimeFrame())
  for _,animSet in ipairs(self:GetAnimationSets()) do
    local pfmAnimSet = udm.PFMAnimationSet()
    animSet:ToPFMAnimationSet(pfmAnimSet)
    pfmFilmClip:GetAnimationSets():PushBack(pfmAnimSet)
  end
end
