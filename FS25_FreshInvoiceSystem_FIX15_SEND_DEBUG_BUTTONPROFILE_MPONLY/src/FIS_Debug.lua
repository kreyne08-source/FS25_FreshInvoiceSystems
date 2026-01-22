
FIS_Debug = {}
FIS_Debug.enabled = false

function FIS_Debug.log(msg)
    if FIS_Debug.enabled then
        print("[FIS DEBUG] " .. tostring(msg))
    end
end
