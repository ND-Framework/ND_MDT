if GetResourceState("es_extended") == "started" then

    ---Convert ESX Job to ND_MDT format
    ---@param job table ESX Job Array
    ---@param rank integer|nil Grade number
    ---@return nil
    ---@return table
    function ConvertJobToJobInfo(job, rank)

        local grades = {}

        for k, v in pairs(job.grades) do
            grades[tonumber(k)] = v.label
        end

        return job.name, {
            label = job.label,
            ranks = grades,
            rankName = rank and grades[tonumber(rank)] or nil
        }

    end
end