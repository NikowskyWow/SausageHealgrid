-- LibStub is a very small versioning library used by nearly all WoW addons.
-- It is public domain and does not require a license.

local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2
local LibStub = _G[LIBSTUB_MAJOR]

if not LibStub or LibStub.minor < LIBSTUB_MINOR then
	LibStub = LibStub or {libs = {}, minors = {} }
	_G[LIBSTUB_MAJOR] = LibStub
	LibStub.minor = LIBSTUB_MINOR
	
	function LibStub:NewLibrary(major, minor)
		if type(major) ~= "string" then error("Bad argument #2 to `NewLibrary' (string expected)", 2) end
		minor = assert(tonumber(strmatch(minor, "%d+")), "Bad argument #3 to `NewLibrary' (number expected)")
		if self.libs[major] and self.minors[major] >= minor then return nil end
		self.minors[major] = minor
		local lib = self.libs[major] or {}
		self.libs[major] = lib
		return lib, major
	end
	
	function LibStub:GetLibrary(major, silent)
		if not self.libs[major] and not silent then error(string.format("Cannot find a library instance of %q.", tostring(major)), 2) end
		return self.libs[major], self.minors[major]
	end
	
	function LibStub:IterateLibraries() return pairs(self.libs) end
	setmetatable(LibStub, { __call = LibStub.GetLibrary })
end
