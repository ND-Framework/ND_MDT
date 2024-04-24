let newCharges = {}
let timeBetweenMessages = []
let cumilativeTimeBetweenMessages;
let bolosLoaded = false
let reportsLoaded = false
const currentDate = new Date()

let reportsViewing = "crime"
let bolosViewing = "all"
let boloList = []
const allBolos = {
    "person": {},
    "vehicle": {},
    "other": {}
}
const allReports = {
    "crime": {},
    "traffic": {},
    "arrest": {},
    "incident": {},
    "use_of_force": {}
}

function fetchCallback(name, data, cb) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json; charset=UTF-8",
        },
        body: JSON.stringify(data)
    }).then(resp => resp.json()).then(resp =>
        cb(resp)
    );
}

function wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function animateHide(e, promise) {
    const timeString = e.css("animation-duration");
    const timeInMs = Math.round(parseFloat(timeString) * 1000);
    e.addClass("hidden");

    if (promise) {
        wait(timeInMs)
        e.hide();
        return;
    }

    setTimeout(() => {
        e.hide();
    }, timeInMs);
}

function animateShow(e) {
    e.removeClass("hidden");
    e.show();
}

function createConfirmScreen(text) {
    return new Promise((resolve, reject) => {
        const e = $(".confirm-screen");

        e.get(-1).style.zIndex = 1000;
        document.body.append(e.get(-1));
    
        $(".confirm-screen > p").text(text);
        animateShow(e);
    
        const timeout = setTimeout(() => {
            animateHide(e);
            reject("Timeout");
        }, 30000);
    
        $(".confirm-screen > div > button").one("click", function() {
            const value = $(this).val();
            animateHide(e);
            clearTimeout(timeout);
            resolve(value);
        });
    });
}

function movePage(element) {
    let shiftX = event.clientX - $(element).get(-1).getBoundingClientRect().left;
    let shiftY = event.clientY - $(element).get(-1).getBoundingClientRect().top;

    $(element).get(-1).style.position = "absolute";
    $(element).get(-1).style.zIndex = 1000;
    document.body.append($(element).get(-1));

    moveAt(event.pageX, event.pageY);

    function moveAt(pageX, pageY) {
        $(element).get(-1).style.left = pageX - shiftX + "px";
        $(element).get(-1).style.top = pageY - shiftY + "px";
    };

    function onMouseMove(event) {
        moveAt(event.pageX, event.pageY);

        $(element).get(-1).hidden = true;
        let elemBelow = document.elementFromPoint(event.clientX, event.clientY);
        $(element).get(-1).hidden = false;

        if (!elemBelow) return;
    };

    document.addEventListener("mousemove", onMouseMove);

    $(element).get(-1).onmouseup = function(e) {
        document.removeEventListener("mousemove", onMouseMove);
        $(element).get(-1).onmouseup = null;
    };

    $(element).get(-1).ondragstart = function() {
        return false;
    };
}
$(".topBarText").mousedown(function(event) {
    movePage(".background")
});
$(".form-records-bar").mousedown(function(event) {
    movePage(".form-records")
});
$(".form-bolo-bar").mousedown(function(event) {
    movePage(".form-bolo")
});
$(".form-reports-bar").mousedown(function(event) {
    movePage(".form-reports")
});

const escapeHtml = (unsafe) => {
    if (!unsafe || unsafe == "" || typeof(unsafe) != "string") {return unsafe}
    return unsafe.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;');
};

// get translation
let translation = {}
$.getJSON("../config/translate.json", function(data) {
    translation = data[0];
    $("#leftPanelButtonDashboard").html(`<i style="margin-left: 2%; font-size: 2ch"class="bx bxs-dashboard"></i> ${translation["Dashboard"]}`);
    $("#leftPanelButtonNameSearch").html(`<i style="margin-left: 4%" class="fas fa-user"></i> ${translation["Name Search"]}`);
    $("#leftPanelButtonPlateSearch").html(`<i class="fas fa-car-side"></i> ${translation["Plate Search"]}`);
    $("#leftPanelButtonWeaponSearch").html(`<i class="fa-solid fa-gun"></i> ${translation["Weapon Search"]}`);
    $("#leftPanelButtonBolo").html(`<i class="fa-solid fa-hand"></i> ${translation["BOLO"]}`);
    $("#leftPanelButtonReports").html(`<i class="fa-solid fa-file"></i> ${translation["Reports"]}`);
    $("#leftPanelButtonLiveChat").html(`<i class="fas fa-comment-alt"></i> ${translation["Live Chat"]}`);
    $("#leftPanelButtonEmployees").html(`<i class="fa-solid fa-users-gear"></i> ${translation["Employees"]}`);
    $("#leftPanelButtonSettings").html(`<i class="fas fa-cog"></i> ${translation["Settings"]}`);
    $("#leftPanelPanicButton").html(translation["PANIC"]);
    $("#rightPanelDashboardBusyButton").text(translation["Busy"]);
    $("#rightPanelDashboardOutServiceButton").text(translation["Out of service"]);
    $("#rightPanelDashboardInServiceButton").text(translation["In service"]);
    $("#rightPanelDashboardPanicButton").text(translation["PANIC"]);
    $("#rightPanelDashboardTrafficStopButton").text(translation["Traffic stop"]);
    $("#rightPanelDashboardTransportButton").text(translation["Transporting to station"]);
    $("#rightPanelDashboardArrivedButton").text(translation["Arrived on scene"]);
    $("#rightPanelDashboardRouteButton").text(translation["En route"]);
    $("#rightPanelDashboardDisplayActiveUnits").text(translation["Active Units"]);
    $("#rightPanelDashboardDisplayCalls").text(translation["Calls"]);
    $(".viewVehiclesButton").html(`<i class="fas fa-car-side"></i> ${translation["View vehicles"]}`);
    $(".viewWeaponsButton").html(`<i class="fa-solid fa-gun"></i> ${translation["View weapons"]}`);
    $(".boloCitizenCreateButton").html(`<i class="fa-solid fa-hand"></i> ${translation["Create BOLO"]}`);
    $(".recordsMainCreateButton").html(`<i class="fa-solid fa-file"></i> ${translation["Create record"]}`);
    $(".recordsCitizenSave").html(`<i class="fa-solid fa-check"></i> ${translation["Save all changes"]}`);
    $(".recordsLicensesTitle").text(`${translation["Licenses"]}:`);
    $(".recordsPropertiesTitle").text(`${translation["Properties"]}:`);
    $(".recordsMainTitle").text(`${translation["Records"]}:`);
    $("#firstNameSearchBar").attr("placeholder", `${translation["First name"]}..`);
    $("#lastNameSearchBar").attr("placeholder", `${translation["Last name"]}..`);
    $("#searchNameDefault").text(`${translation["Search citizen by name"]}.`);
    $("#plateSearchBar").attr("placeholder", translation["Plate number"]);
    $("#searchPlateDefault").text(`${translation["Search vehicle by plate number"]}.`);
    $("#weaponSearchBar").attr("placeholder", translation["Weapon serial number"]);
    $("#searchWeaponDefault").text(`${translation["Search weapon by serial number"]}.`);
    $(".rightPanelBoloButtons button[value=\"all\"]").text(translation["All Bolo"]);
    $(".rightPanelBoloButtons button[value=\"vehicle\"]").text(translation["Vehicle Bolo"]);
    $(".rightPanelBoloButtons button[value=\"person\"]").text(translation["Person Bolo"]);
    $(".rightPanelBoloButtons button[value=\"other\"]").text(translation["Other Bolo"]);
    $(".rightPanelBoloButtons button[value=\"create\"]").text(translation["Create Bolo"]);
    $(".rightPanelReportsButtons button[value=\"crime\"]").text(translation["Crime"]);
    $(".rightPanelReportsButtons button[value=\"traffic\"]").text(translation["Traffic"]);
    $(".rightPanelReportsButtons button[value=\"arrest\"]").text(translation["Arrest"]);
    $(".rightPanelReportsButtons button[value=\"incident\"]").text(translation["Incident"]);
    $(".rightPanelReportsButtons button[value=\"use_of_force\"]").text(translation["Use of Force"]);
    $(".rightPanelReportsButtons button[value=\"create\"]").text(translation["Create report"]);
    $(".liveChatRateLimit").text(translation["You've been rate limited, wait for this message to dissapear."]);
    $(".form-records-bar").text(translation["Create record"]);
    $("#form-bolo-create, #form-reports-create, #form-records-create").text(translation["Create"]);
    $(".form-bolo-bar").text(translation["Create BOLO"]);
    $(".form-bolo-type option[value=\"\"]").text(translation["Choose bolo Type"]);
    $(".form-bolo-type option[value=\"person\"]").text(translation["Person"]);
    $(".form-bolo-type option[value=\"vehicle\"]").text(translation["Vehicle"]);
    $(".form-bolo-type option[value=\"other\"]").text(translation["Other"]);
    $(".form-reports-bar").text(translation["Create report"]);
    $(".form-reports-type option[value=\"\"]").text(translation["Choose report type"]);
    $(".form-reports-type option[value=\"crime\"]").text(translation["Crime"]);
    $(".form-reports-type option[value=\"traffic\"]").text(translation["Traffic"]);
    $(".form-reports-type option[value=\"arrest\"]").text(translation["Arrest"]);
    $(".form-reports-type option[value=\"incident\"]").text(translation["Incident"]);
    $(".form-reports-type option[value=\"use_of_force\"]").text(translation["Use of Force"]);
    $(".confirm-screen > div button[value=\"confirm\"]").text(translation["Confirm"]);
    $(".confirm-screen > div button[value=\"cancel\"]").text(translation["Cancel"]);
});

// Hide all pages but the dashboard on start.
$(".rightPanelNameSearch, .rightPanelPlateSearch, .rightPanelWeaponSearch, .rightPanelBoloPage, .rightPanelReportsPage, .rightPanelLiveChat, .rightPanelEmployees, .rightPanelSettings").hide();

// This function will hide all pages and reset the background-color for the menu buttons. This is used when changing pages to display another page.
function hideAllPages() {
    $(".rightPanelDashboard, .rightPanelNameSearch, .rightPanelPlateSearch, .rightPanelWeaponSearch, .rightPanelBoloPage, .rightPanelReportsPage, .rightPanelLiveChat, .rightPanelEmployees, .rightPanelSettings").hide();
    $(".leftPanelButtons").css("background-color", "transparent");
};

// display vehicle information on the vehicle search panel.
function createWeaponSearchResult(data) {
    $(".rightPanelWeaponSearchResponses").empty();
    $("#searchWeaponDefault").text("");
    for (const [key, value] of Object.entries(data)) {
        if (key && value) {
            $(".rightPanelWeaponSearchResponses").append(`
                <div class="plateSearchResult">
                    <div class="plateSearchResultContainer">
                        <div class="weaponSearchResultGrid">
                            <div>
                                <p class="plateSearchResultProperty">${translation["Owner"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.ownerName)}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Weapon type"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(vehicleText(value.weapon))}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Serial number"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.serial)}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Stolen status"]}:</p>
                                ${value.stolen && `<p class="plateSearchResultValue weapon_${value.serial}" style="color: red;">${translation["Stolen"]}</p>` || `<p class="plateSearchResultValue weapon_${value.serial}">${translation["Not stolen"]}</p>`}
                            </div>
                        </div>
                    </div>
                    <div class="searchButtons">
                        <Button class="weaponSearchResultButton" data-id="${value.characterId}">${translation["Search citizen"]}</Button>
                        ${value.stolen && `<Button style="background-color: #494e59;" class="setWeaponStolen" data-serial="${value.serial}">${translation["Mark found"]}</Button>` || `<Button style="background-color: #2656c9" class="setWeaponStolen" data-serial="${value.serial}">${translation["Mark stolen"]}</Button>`}
                    </div>
                </div>
            `);
        };
    };

};

$(document).on("click", ".setWeaponStolen", function() {
    const e = $(this);
    const serial = e.data("serial");
    const stolen = e.text() == translation["Mark stolen"]
    const status = $(`.weapon_${serial}`);
    $.post(`https://${GetParentResourceName()}/weaponStatus`, JSON.stringify({
        serial: serial,
        stolen: stolen
    }));
    if (stolen) {
        e.text(translation["Mark found"]);
        e.css("background-color", "#494e59");
        status.text(translation["Stolen"]);
        status.css("color", "red");
    } else {
        e.text(translation["Mark stolen"]);
        e.css("background-color", "#2656c9");
        status.text(translation["Not stolen"]);
        status.css("color", "#ccc");
    }
    return false;
});

$(document).on("click", ".weaponSearchResultButton", function() {
    $(".rightPanelNameSearchResponses").show();
    $(".rightPanelNameSearchResponses").empty();
    $("#searchNameDefault").text("");
    $("#nameLoader").fadeIn("fast");
    $("body").css("cursor", "progress")
    $.post(`https://${GetParentResourceName()}/nameSearch`, JSON.stringify({
        id: $(this).data("id")
    }));

    hideAllPages();
    $(".rightPanelNameSearch").fadeIn("fast");
    $("#leftPanelButtonNameSearch").css("background-color", "#3a3b3c");
    return false;
});

// Reset all unit status buttons highlight on the dashboard. This is used to reset all of them then highlight another one (the active one).
function resetStatus() {
    $(".rightPanelDashboardButtonsStatus").css({
        "color":"#ccc",
        "opacity":"0.5"
    });
};

// display character information on the name search panel.
function createNameSearchResult(data) {
    for (const [key, value] of Object.entries(data)) {
        if (key && value) {
            $(".rightPanelNameSearchResponses").append(`
                <div class="nameSearchResult" data-character="${value.characterId}">
                    <div class="nameSearchResultImageContainer">
                        <img class="nameSearchResultImage" src="${value.img}">
                    </div>
                    <div class="nameSearchResultInfo">
                        <p class="nameSearchResultProperty">${translation["First Name"]}:</p>
                        <p class="nameSearchResultValue">${escapeHtml(value.firstName)}</p>
                        <p class="nameSearchResultProperty">${translation["Last Name"]}:</p>
                        <p class="nameSearchResultValue">${escapeHtml(value.lastName)}</p>
                    </div>
                    <div class="nameSearchResultInfo">
                        <p class="nameSearchResultProperty">${translation["Date of Birth"]}:</p>
                        <p class="nameSearchResultValue">${escapeHtml(value.dob)}</p>
                        <p class="nameSearchResultProperty">${translation["Gender"]}:</p>
                        <p class="nameSearchResultValue">${escapeHtml(value.gender)}</p>
                    </div>
                    ${(value.phone || value.ethnicity) &&
                        `<div class="nameSearchResultInfo">
                            ${value.ethnicity && `<p class="nameSearchResultProperty">${translation["Ethnicity"]}:</p><p class="nameSearchResultValue">${value.ethnicity}</p>` || ""}
                            ${value.phone && `<p class="nameSearchResultProperty">${translation["Phone number"]}:</p><p class="nameSearchResultValue">${value.phone}</p>` || ""}
                        </div>`
                    || ""}
                    <div class="nameSearchResultButtons">
                        <Button class="nameSearchResultButtonWeapons nameSearchResultButton" data-character="${value.characterId}">${translation["View Weapons"]}</Button>
                        <br>
                        <Button class="nameSearchResultButtonVehicles nameSearchResultButton" data-character="${value.characterId}">${translation["View Vehicles"]}</Button>
                    </div>
                </div>
            `);
        };
    };

};

$(document).on("click", ".nameSearchResult", function() {
    $("#nameLoader").fadeIn("fast");
    $("body").css("cursor", "progress")
    $.post(`https://${GetParentResourceName()}/viewRecords`, JSON.stringify({
        id: $(this).data("character")
    }));
    return false;
});

$(document).on("click", ".nameSearchResultButtonWeapons", function() {
    $("#weaponLoader").fadeIn("fast");
    $("body").css("cursor", "progress")
    $.post(`https://${GetParentResourceName()}/viewWeapons`, JSON.stringify({
        search: $(this).data("character"),
        searchBy: "owner"
    }));
    return false;
});

$(document).on("click", ".nameSearchResultButtonVehicles", function() {
    $("#plateLoader").fadeIn("fast");
    $("body").css("cursor", "progress")
    $.post(`https://${GetParentResourceName()}/viewVehicles`, JSON.stringify({
        search: $(this).data("character"),
        searchBy: "owner"
    }));
    return false;
});

function vehicleText(text) {
    let txt = text
    if (txt == "NULL" || !txt) {
        txt = translation["Not found"];
    };
    return txt;
};

// display vehicle information on the vehicle search panel.
function createVehicleSearchResult(data) {
    $(".rightPanelPlateSearchResponses").empty();
    $("#searchPlateDefault").text("");
    for (const [key, value] of Object.entries(data)) {
        if (key && value) {
            $(".rightPanelPlateSearchResponses").append(`
                <div class="plateSearchResult">
                    <div class="plateSearchResultContainer">
                        <div class="plateSearchResultGrid">
                            <div>
                                <p class="plateSearchResultProperty">${translation["Owner"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.character.firstName)} ${escapeHtml(value.character.lastName)}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Plate"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.plate)}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Color"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.color)}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Stolen status"]}:</p>
                                ${value.stolen && `<p class="plateSearchResultValue vehicle_${value.id}" style="color: red;">Stolen</p>` || `<p class="plateSearchResultValue vehicle_${value.id}">${translation["Not stolen"]}</p>`}
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Make"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(vehicleText(value.make))}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Model"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(vehicleText(value.model))}</p>
                            </div>
                            <div>
                                <p class="plateSearchResultProperty">${translation["Class"]}:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.class)}</p>
                            </div>
                        </div>
                    </div>
                    <div class="searchButtons" style="margin-top: 3.5%">
                        <Button class="plateSearchResultButton" data-first="${value.character.firstName}" data-last="${value.character.lastName}">${translation["Search citizen"]}</Button>
                        ${value.stolen && `<Button style="background-color: #494e59;" class="setVehicleStolen" data-id="${value.id}" data-plate="${value.plate}">${translation["Mark found"]}</Button>` || `<Button style="background-color: #2656c9" class="setVehicleStolen" data-id="${value.id}">${translation["Mark stolen"]}</Button>`}
                    </div>
                </div>
            `);
        };
    };

};

$(document).on("click", ".setVehicleStolen", function() {
    const e = $(this);
    const id = e.data("id");
    const stolen = e.text() == translation["Mark stolen"]
    const status = $(`.vehicle_${id}`);
    $.post(`https://${GetParentResourceName()}/vehicleStatus`, JSON.stringify({
        id: id,
        stolen: stolen,
        plate: e.data("plate")
    }));
    if (stolen) {
        e.text(translation["Mark found"]);
        e.css("background-color", "#494e59");
        status.text(translation["Stolen"]);
        status.css("color", "red");
    } else {
        e.text(translation["Mark stolen"]);
        e.css("background-color", "#2656c9");
        status.text(translation["Not stolen"]);
        status.css("color", "#ccc");
    }
    return false;
});

$(document).on("click", ".plateSearchResultButton", function() {
    $(".rightPanelNameSearchResponses").show();
    $(".rightPanelNameSearchResponses").empty();
    $("#searchNameDefault").text("");
    $("#nameLoader").fadeIn("fast");
    $("body").css("cursor", "progress")
    $.post(`https://${GetParentResourceName()}/nameSearch`, JSON.stringify({
        first: $(this).data("first"), 
        last: $(this).data("last")
    }));

    hideAllPages();
    $(".rightPanelNameSearch").fadeIn("fast");
    $("#leftPanelButtonNameSearch").css("background-color", "#3a3b3c");
    return false;
});

function formatDate(timeStamp) {
    const date = new Date(timeStamp < 1000000000000 ? timeStamp * 1000 : timeStamp);
    return `${date.getDate()}/${date.getMonth()+1}/${date.getFullYear()}`;
};

// create employee profile
function createEmployee(data) {
    $(".rightPanelEmployeeSearchResponses").append(`
        <div class="nameSearchEmployeeResult" data-character="${data.charId}">
            <div class="nameSearchResultImageContainer">
                <img class="nameSearchResultImage" src="${data.img || "user.jpg"}">
            </div>
            <div class="nameSearchResultInfo">
                <p class="nameSearchResultProperty">${translation["First Name"]}:</p>
                <p class="nameSearchResultValue">${escapeHtml(data.first)}</p>
                <p class="nameSearchResultProperty">${translation["Last Name"]}:</p>
                <p class="nameSearchResultValue">${escapeHtml(data.last)}</p>
            </div>
            <div class="nameSearchResultInfo">
                <p class="nameSearchResultProperty">${translation["Date of Birth"]}:</p>
                <p class="nameSearchResultValue">${escapeHtml(data.dob)}</p>
                <p class="nameSearchResultProperty">${translation["Gender"]}:</p>
                <p class="nameSearchResultValue">${escapeHtml(data.gender)}</p>
            </div>
            ${data.jobInfo && 

                `<div class="nameSearchResultInfo">
                    <p class="nameSearchResultProperty">${translation["Department"]}:</p>
                    <p class="nameSearchResultValue">${escapeHtml(data.jobInfo.label)}</p>
                    <p class="nameSearchResultProperty">${translation["Rank"]}:</p>
                    <p class="nameSearchResultValue" data-characterrank="${data.charId}">${escapeHtml(data.jobInfo.rankName)}</p>
                </div>`

                || ""
            }

            ${(data.phone || data.callsign) &&

                `<div class="nameSearchResultInfo">
                    ${data.callsign && `<p class="nameSearchResultProperty">${translation["Callsign"]}:</p><p class="nameSearchResultValue" data-charactercallsign="${data.charId}">${data.callsign}</p>` || ""}
                    ${data.phone && `<p class="nameSearchResultProperty">${translation["Phone number"]}:</p><p class="nameSearchResultValue">${data.phone}</p>` || ""}
                </div>`

                || ""
            }

            <div class="nameSearchResultButtons">
                <Button class="nameSearchResultButton employeeSearchResultButton" data-character="${data.charId}" data-job="${data.job}" data-action="rank">${translation["Change Rank"]}</Button>
                <br>
                <Button class="nameSearchResultButton employeeSearchResultButton" data-character="${data.charId}" data-action="callsign">${translation["Change Callsign"]}</Button>
                <br>
                <Button class="nameSearchResultButton employeeSearchResultButton" data-character="${data.charId}" data-action="fire" style="background-color:#c22525;">${translation["Fire Employee"]}</Button>
            </div>
        </div>
    `);
}

$(document).on("click", ".employeeSearchResultButton", async function() {
    const th = $(this);
    const action = th.data("action");
    const character = th.data("character");
    let data = null;

    if (action == "rank") {
        // $(".background, .form-records, .form-bolo, .form-reports").fadeOut("fast");
        // $.post(`https://${GetParentResourceName()}/close`);
        data = th.data("job");
    } else if (action == "callsign") {
        // $(".background, .form-records, .form-bolo, .form-reports").fadeOut("fast");
        // $.post(`https://${GetParentResourceName()}/close`);
    } else if (action == "fire") {
        const result = await createConfirmScreen(translation["This action will fire this employee, are you sure you'd like to continue?"])
        if (result != "confirm") {return}
    }

    fetchCallback("empoyeeAction", {
        character: character,
        action: action,
        data: data
    }, function(resp) {
        if (action == "rank") {
            const element = document.querySelector(`.nameSearchResultValue[data-characterrank="${character}"]`);
            element.textContent = escapeHtml(resp);
        } else if (action == "callsign") {
            const element = document.querySelector(`.nameSearchResultValue[data-charactercallsign="${character}"]`);
            element.textContent = escapeHtml(resp);
        } else if (action == "fire") {
            const element = document.querySelector(`.nameSearchEmployeeResult[data-character="${character}"]`);
            element.remove();
        }
    });
})

// add new employee
$(document).on("click", ".newEmployeeButton", function() {
    $.post(`https://${GetParentResourceName()}/newEmployee`);
})


// Creates a records page for a citizen with options to give citation and all that.
function createRecordsPage(data) {
    newCharges = {}

    $(".recordsReturn").click(function() {
        $(".recordsPage").hide();
        $("#nameSearch").show();
        newCharges = {}
    });

    if (!data || !data.citizen) {
        return;
    };

    $(".recordsCitizen, .recordsPropertiesInfo, .recordsLicensesInfo, .recordsMainInfo").empty();
    $(".viewVehiclesButton, .viewWeaponsButton, .recordsMainCreateButton, .recordsCitizenSave").data("character", data.citizen.characterId)
    $(".boloCitizenCreateButton").data("character", {
        id: data.citizen.characterId,
        firstName: data.citizen.firstName,
        lastName: data.citizen.lastName,
        gender: data.citizen.gender,
        ethnicity: data.citizen.ethnicity,
        notes: data.records.notes || ""
    });

    $(".recordsCitizen").append(`
        <div class="recordsCitizenImageContainer">
            <img class="recordsCitizenImage" src="${data.citizen.img || "user.jpg"}">
        </div>
        <div class="recordsCitizenInfo" style="min-width: 14%;">
            <p class="recordsCitizenProperty">${translation["First Name"]}:</p>
            <p class="recordsCitizenValue">${escapeHtml(data.citizen.firstName)}</p>
            <p class="recordsCitizenProperty">${translation["Last Name"]}:</p>
            <p class="recordsCitizenValue">${escapeHtml(data.citizen.lastName)}</p>
            ${data.citizen.ethnicity && `<p class="recordsCitizenProperty">${translation["Ethnicity"]}:</p><p class="recordsCitizenValue">${escapeHtml(data.citizen.ethnicity)}</p>` || data.citizen.phone && `<p class="recordsCitizenProperty">${translation["Phone number"]}:</p><p class="recordsCitizenValue">${escapeHtml(data.citizen.phone)}</p>` || ""}
        </div>
        <div class="recordsCitizenInfo">
            <p class="recordsCitizenProperty">${translation["Date of Birth"]}:</p>
            <p class="recordsCitizenValue">${escapeHtml(data.citizen.dob)}</p>
            <p class="recordsCitizenProperty">${translation["Gender"]}:</p>
            <p class="recordsCitizenValue">${escapeHtml(data.citizen.gender)}</p>
            ${data.citizen.ethnicity && data.citizen.phone && `<p class="recordsCitizenProperty">${translation["Phone number"]}:</p><p class="recordsCitizenValue">${escapeHtml(data.citizen.phone)}</p>` || ""}
        </div>
        <div class="recordsCitizenNotes">
            <p class="recordsCitizenNotesTitle">${translation["Notes"]}:</p>
            <textarea id="recordsCitizenNotesText" data-character="${data.citizen.characterId}"></textarea>
        </div>
    `);
    
    if (data.records.notes) {
        $("#recordsCitizenNotesText").val(escapeHtml(data.records.notes));
    };

    if (data.records.charges) {
        const charges = data.records.charges
        for (let i = 0; i < charges.length; i++) {
            const charge = charges[i]
            $(".recordsMainInfo").prepend(`
                <div class="recordsMainItem">
                    <div class="recordsMainInfraction">
                        <p class="recordsMainInfractionTitle">${charge.crime}:</p>
                        <p class="recordsMainInfractionValue">${translation["Date"]}: ${formatDate(charge.timestamp)} ${charge.fine && `| ${translation["Fine"]}: $${charge.fine}` || ""}</p>
                    </div>
                    <p class="recordsMainType">${charge.type == "infractions" && translation["Infraction"] || charge.type == "misdemeanours" && translation["Misdemeanour"] || charge.type == "felonies" && translation["Felony"]}</p>
                </div>
            `)
        };
    }

    if (data.properties) {
        for (let i = 0; i < data.properties.length; i++) {
            $(".recordsPropertiesInfo").prepend(`
                <div class="recordsPropertiesItem">
                    <p class="recordsPropertiesAddress">${data.properties[i]}</p>
                </div>
            `);
        };
    };

    if (data.licenses) {
        for (let i = 0; i < data.licenses.length; i++) {
            $(".recordsLicensesInfo").prepend(`
                <div class="recordsLicensesItem">
                    <div class="recordsLicenseContainer">
                        <p class="recordsLicenseBig">${translation["Type"]}:</p>
                        <p class="recordsLicenseSmall">${data.licenses[i].type}</p>
                    </div>
                    <div class="recordsLicenseContainer">
                        <p class="recordsLicenseBig">${translation["Status"]}:</p>
                        <select id="recordsLicenseSelect${i}" class="recordsLicenseSmallDropDown" data-id="${data.licenses[i].identifier}">
                            <option value="valid">${translation["Vaild"]}</option>
                            <option value="suspended">${translation["Suspended"]}</option>
                            <option value="expired">${translation["Expired"]}</option>
                        </select>
                    </div>
                    <div class="recordsLicenseContainer">
                        <p class="recordsLicenseBig">${data.licenses[i].issued !== undefined ? (translation["Issued"] + ":") : ""}</p>
                        <p class="recordsLicenseSmall">${data.licenses[i].issued !== undefined ? formatDate(data.licenses[i].issued) : ""}</p>
                    </div>
                    <div class="recordsLicenseContainer">
                        <p class="recordsLicenseBig">${data.licenses[i].expires !== undefined ? (translation["Expires"] + ":") : ""}</p>
                        <p class="recordsLicenseSmall">${data.licenses[i].expires !== undefined ? formatDate(data.licenses[i].expires) : ""}</p>
                    </div>
                </div>
            `);
            $(`#recordsLicenseSelect${i}`).val(data.licenses[i].status);
        };
    };

    $(".recordsLicenseSmallDropDown").change(function() {
        $.post(`https://${GetParentResourceName()}/licenseDropDownChange`, JSON.stringify({
            identifier: $(this).data("id"),
            value: $(this).val()
        }));
    });

};

// load penal codes/charges into page.
function getCrimes(penal, type) {
    let string = ""
    for (const [key, value] of Object.entries(penal)) {
        string = `${string}<option value="${key}" data-type="${type}">${value.crime}</option>`
    }
    return string
}

let penal = {}
$.getJSON("../config/charges.json", function(data) {
    penal = data[0]

    // add charges to list
    for (const [key, value] of Object.entries(penal)) {
        $("#form-records-charges").append(`
            <optgroup label="${key}">
                ${getCrimes(value, key)}
            </optgroup>
        `);
    }

    // set default record page
    const first = data[0].infractions[0]
    $(".form-records-description-value").text(first.description);
    $(".form-records-sentence").text(first.sentence && `${translation["Up to"]} ${first.sentence} ${translation["months sentence"]}` || "");
    if (first.fine) {
        const fineDivision = first.fine/4
        $(".form-records-fine").html(`Fine: <select class="form-records-fine-select"><option>$${fineDivision*4}</option><option>$${fineDivision*3}</option><option>$${fineDivision*2}</option><option>$${fineDivision}</option></select>`);
    } else {
        $(".form-records-fine").text("Fine: none");
    }
});

// Update record page
$(document).on("change", "#form-records-charges", function() {
    const e = $(this)
    const chargeNum = e.val();
    const chargeType = e.find(":selected").data("type")
    const charge = penal[chargeType][chargeNum]
    $(".form-records-description-value").text(charge.description);
    $(".form-records-sentence").text(charge.sentence && `${translation["Up to"]} ${charge.sentence} ${translation["months sentence"]}` || "");
    if (charge.fine) {
        const fineDivision = charge.fine/4
        $(".form-records-fine").html(`${translation["Fine"]}: <select class="form-records-fine-select"><option>$${fineDivision*4}</option><option>$${fineDivision*3}</option><option>$${fineDivision*2}</option><option>$${fineDivision}</option></select>`);
    } else {
        $(".form-records-fine").text(`${translation["Fine"]}: ${translation["none"]}`);
    }
});

// Confirm create a record
$(document).on("click", "#form-records-create", function() {
    const e = $("#form-records-charges")
    const chargeNum = e.val();
    const chargeType = e.find(":selected").data("type")
    const fine = $(".form-records-fine-select").val()
    const charge = penal[chargeType][chargeNum]
    newCharges[newCharges.length+1] = {
        chargeNum: chargeNum,
        chargeType: chargeType,
        fine: fine
    }
    const el = $(`
        <div class="recordsMainItem" style="display: none;">
            <div class="recordsMainInfraction">
                <p class="recordsMainInfractionTitle">${charge.crime}:</p>
                <p class="recordsMainInfractionValue">${translation["Date"]}: ${formatDate(Math.floor(Date.now() / 1000))} ${fine && `| ${translation["Fine"]}: ${fine}` || ""}</p>
            </div>
            <p class="recordsMainType">${chargeType == "infractions" && translation["Infraction"] || chargeType == "misdemeanours" && translation["Misdemeanour"] || chargeType == "felonies" && translation["Felony"]}</p>
        </div>
    `)
    $(".recordsMainInfo").prepend(el)
    el.slideToggle();
});

// close the whole ui when the X square is clicked.
$(".form-records-close").click(function() {
    $(".form-records").fadeOut();
});
$(".form-bolo-close").click(function() {
    $(".form-bolo").fadeOut();
    setTimeout(() => {
        $(".form-bolo-type").val("");
        $(".form-bolo-content").empty(); 
    }, 250);
});
$(".form-reports-close").click(function() {
    $(".form-reports").fadeOut();
    setTimeout(() => {
        $(".form-reports-type").empty().append(`
            <option value="" disabled selected hidden>Choose report type</option>
            <option value="crime">Crime</option>
            <option value="traffic">Traffic</option>
            <option value="arrest">Arrest</option>
            <option value="incident">Incident</option>
            <option value="use_of_force">Use of Force</option>
        `)
        $(".form-reports-content > textarea, .form-reports-content > input").val("");
    }, 250);
});

$(".recordsPageTopButton").click(function() {
    const text = $(this).text()
    const character = $(this).data("character")
    
    if (text == ` ${translation["View vehicles"]}`) {
        $("#plateLoader").fadeIn("fast");
        $("body").css("cursor", "progress")
        $.post(`https://${GetParentResourceName()}/viewVehicles`, JSON.stringify({
            search: character,
            searchBy: "owner"
        }));
    } else if (text == " View weapons") {
        $("#weaponLoader").fadeIn("fast");
        $("body").css("cursor", "progress")
        $.post(`https://${GetParentResourceName()}/viewWeapons`, JSON.stringify({
            search: character,
            searchBy: "owner"
        }));
    } else if (text == ` ${translation["Create BOLO"]}`) {
        const e = $(".form-bolo")
        e.fadeIn();
        e.get(-1).style.zIndex = 1000;
        document.body.append(e.get(-1));

        $(".form-records-content > select").val(translation["person"])

        const content = $(".form-bolo-content");
        content.empty();

        const el = $(`<div style="display: none;" data-character="${character.id}">
            <input type="text" placeholder="${translation["First Name"]}" value="${character.firstName}"/>
            <input type="text" placeholder="${translation["Last Name"]}" value="${character.lastName}"/>
            <input type="text" placeholder="${translation["Ethnicity"]}" value="${character.ethnicity}"/>
            <select required>
                ${character.gender == translation["Male"] && `<option value="${translation["Male"]}" selected>${translation["Male"]}</option><option value="${translation["Female"]}" disabled>${translation["Female"]}</option>` || `<option value="${translation["Male"]}" disabled>${translation["Male"]}</option><option value="${translation["Female"]}" selected>${translation["Female"]}</option>`}
            </select>
            <textarea placeholder="${translation["BOLO information"]}"></textarea>
        </div>`)
        
        content.prepend(el)
        el.slideToggle();
    } else if (text == ` ${translation["Create record"]}`) {
        const e = $(".form-records")
        e.fadeIn();
        e.get(-1).style.zIndex = 1000;
        document.body.append(e.get(-1));
    } else if (text == ` ${translation["Save all changes"]}`) {
        $.post(`https://${GetParentResourceName()}/saveRecords`, JSON.stringify({
            character: character,
            notes: $("#recordsCitizenNotesText").val(),
            newCharges: newCharges
        }));
        newCharges = {}
    }

});

// Confirm create bolo
$("#form-bolo-create").click(function() {
    const type = $(".form-bolo-type").val();
    
    if (type === "person") {
        const character = $(".form-bolo-content > div").data("character");
        const nameFrist = $(".form-bolo-content > div > input:nth-child(1)").val();
        const nameLast = $(".form-bolo-content > div > input:nth-child(2)").val();
        const ethnicity = $(".form-bolo-content > div > input:nth-child(3)").val();
        const gender = $(".form-bolo-content > div > select").val();
        const info = $(".form-bolo-content > div > textarea").val();
        $.post(`https://${GetParentResourceName()}/createBolo`, JSON.stringify({
            type: type,
            character: character,
            firstName: nameFrist,
            lastName: nameLast,
            ethnicity: ethnicity,
            gender: gender,
            info: info
        }));
    } else if (type === "vehicle") {
        const plate = $(".form-bolo-content > div > input:nth-child(1)").val();
        const color = $(".form-bolo-content > div > input:nth-child(2)").val();
        const make = $(".form-bolo-content > div > input:nth-child(3)").val();
        const model = $(".form-bolo-content > div > input:nth-child(4)").val();
        const info = $(".form-bolo-content > div > textarea").val();
        $.post(`https://${GetParentResourceName()}/createBolo`, JSON.stringify({
            type: type,
            plate: plate,
            color: color,
            make: make,
            model: model,
            info: info
        }));
    } else {
        const info = $(".form-bolo-content > div > textarea").val();
        $.post(`https://${GetParentResourceName()}/createBolo`, JSON.stringify({
            type: "other",
            info: info
        }));
    }

    $(".form-bolo").fadeOut();
    setTimeout(() => {
        $(".form-bolo-type").val("");
        $(".form-bolo-content").empty();
    }, 250);
    if ($(".rightPanelBoloPage").css("display") == "block") {
        return;
    };
    if (!bolosLoaded) {
        $.post(`https://${GetParentResourceName()}/getBolos`);
        bolosLoaded = true
    }
    hideAllPages();
    $(".rightPanelBoloPage").fadeIn("fast");
    $("#leftPanelButtonBolo").css("background-color", "#3a3b3c");
});

// Confirm create report
$("#form-reports-create").click(function() {
    const type = $(".form-reports-type").val();
    const location = $(".form-reports-content > input").val();
    const info = $(".form-reports-content > textarea").val();

    $.post(`https://${GetParentResourceName()}/createReport`, JSON.stringify({
        type: type,
        info: info,
        location: location
    }));

    $(".form-reports").fadeOut();
    setTimeout(() => {
        $(".form-reports-type").empty().append(`
            <option value="" disabled selected hidden>Choose report type</option>
            <option value="crime">Crime</option>
            <option value="traffic">Traffic</option>
            <option value="arrest">Arrest</option>
            <option value="incident">Incident</option>
            <option value="use_of_force">Use of Force</option>
        `)
        $(".form-reports-content > textarea, .form-reports-content > input").val("");
    }, 250);
    if ($(".rightPanelReportsPage").css("display") == "block") {
        return;
    };
    if (!reportsLoaded) {
        $.post(`https://${GetParentResourceName()}/getReports`);
        reportsLoaded = true
    }
    hideAllPages();
    $(".rightPanelReportsPage").fadeIn("fast");
    $("#leftPanelButtonReports").css("background-color", "#3a3b3c");
});

$(document).on("click", ".report-delete", async function() {
    const id = $(this).data("id");
    const result = await createConfirmScreen(translation["Are you sure you'd like to remove this report?"])
    if (result != "confirm") {return}
    $.post(`https://${GetParentResourceName()}/removeReport`, JSON.stringify({
        id: id
    }));
});

$(".form-records-content > select").change(function() {
    const e = $(this);
    const content = $(".form-bolo-content");
    content.empty();
    const value = e.val();
    if (value == "person") {
        const el = $(`<div style="display: none;">
            <input type="text" placeholder="${translation["First Name"]}"/>
            <input type="text" placeholder="${translation["Last Name"]}"/>
            <input type="text" placeholder="${translation["Ethnicity"]}"/>
            <select required>
                <option value="" disabled selected hidden>${translation["Gender"]}</option>
                <option value="${translation["Male"]}">${translation["Male"]}</option>
                <option value="${translation["Female"]}">${translation["Female"]}</option>
            </select>
            <textarea placeholder="${translation["BOLO information"]}"></textarea>
        </div>`)
        content.prepend(el)
        el.slideToggle();
    } else if (value == "vehicle") {
        const el = $(`<div style="display: none;">
            <input type="text" placeholder="${translation["Plate"]}"/>
            <input type="text" placeholder="${translation["Color"]}"/>
            <input type="text" placeholder="${translation["Make"]}"/>
            <input type="text" placeholder="${translation["Model"]}"/>
            <textarea placeholder="${translation["BOLO information"]}"></textarea>
        </div>`)
        content.prepend(el)
        el.slideToggle();
    } else if (value == "other") {
        const el = $(`<div style="display: none; grid-template-rows: 1fr;">
            <textarea placeholder="${translation["BOLO information"]}"></textarea>
        </div>`)
        content.prepend(el)
        el.slideToggle();
    } 
});

// sends a chat message in the mdt live chat.
function createLiveChatMessage(callsign, dept, imageURL, username, text) {
    $(".rightPanelLiveChatBox").animate({ scrollTop: $(document).height() + $(window).height() }, "slow");
    $(".rightPanelLiveChatBox").append(`
        <div class="liveChatMessage">
            <div class="liveChatImageContainer">
                <img class="liveChatImage" src="${imageURL}">
            </div>
            <div class="liveChatNameAndMessage">
                <div class="liveChatMessageName">${escapeHtml(username)} <div class="hintCallSignAndDept">${escapeHtml(callsign)} [${escapeHtml(dept)}]</div></div>
                <p class="liveChatMessageText">${escapeHtml(text)}</p>
            </div>
        </div>
    `);
};

function viewReport(report, animate) {
    if (!report) {return}
    const data = JSON.parse(report.data)
    const e = $(".rightPanelReportsResponses")

    el = $(`
        <div class="reportBox" style="${animate && `display: none;` || ""}" data-id="${report.id}">
            <div>
                <p class="nameSearchResultProperty">${translation["Officer"]}:</p>
                <p class="nameSearchResultValue" style="margin-bottom: 5%">${escapeHtml(data.officer)}</p>
                <p class="nameSearchResultProperty">${translation["Location"]}:</p>
                <p class="nameSearchResultValue">${escapeHtml(data.location)}</p>
            </div>
            <div style="margin-right: 5%">
                ${data.info &&
                    `<p class="nameSearchResultProperty">${translation["Description"]}:</p>
                    <p class="nameSearchResultValue" style="margin-bottom: 0">${escapeHtml(data.info)}</p>`
                || ""}
            </div>
            <div>
                <p class="nameSearchResultValue"><b>${translation["Case ID"]}:</b> ${report.id}</p>
                <Button class="nameSearchResultButtonVehicles nameSearchResultButton report-delete" style="margin: 0;" data-id="${report.id}">${translation["Remove report"]}</Button>
            </div>
        </div>
    `)

    e.prepend(el)
    if (animate) {el.slideToggle()}
}

function viewBolo(bolo, animate) {
    if (!bolo) {return}
    const data = JSON.parse(bolo.data)
    const e = $(".rightPanelBoloResponses")
    let el = ""
    if (bolo.type == "person") {
        el = $(`
            <div class="boloBox" style="${animate && `display: none;` || ""}" data-id="${bolo.id}">
                <div class="nameSearchResultImageContainer"><img class="nameSearchResultImage" src="${data.img || "user.jpg"}"/></div>
                <div>
                    <p class="nameSearchResultProperty">${translation["First Name"]}:</p>
                    <p class="nameSearchResultValue" style="margin-bottom: 5%">${escapeHtml(data.firstName)}</p>
                    <p class="nameSearchResultProperty">${translation["Last Name"]}:</p>
                    <p class="nameSearchResultValue">${escapeHtml(data.lastName)}</p>
                </div>
                <div>
                    <p class="nameSearchResultProperty">${translation["Ethnicity"]}:</p>
                    <p class="nameSearchResultValue" style="margin-bottom: 5%">${escapeHtml(data.ethnicity)}</p>
                    <p class="nameSearchResultProperty">${translation["Gender"]}:</p>
                    <p class="nameSearchResultValue">${escapeHtml(data.gender)}</p>
                </div>
                <div style="margin-right: 2%">
                    ${data.info &&
                        `<p class="nameSearchResultProperty">${translation["Description"]}:</p>
                        <p class="nameSearchResultValue" style="margin-bottom: 0">${escapeHtml(data.info)}</p>`
                    || ""}
                </div>
                <div>
                    ${data.character && `
                        <button class="nameSearchResultButton bolo-viewCitzen" data-id="${data.character}">${translation["Search citizen"]}</button>
                        <br>
                        <button class="nameSearchResultButton bolo-delete" data-id="${bolo.id}">${translation["Remove Bolo"]}</button>
                    ` || `<Button class="nameSearchResultButton bolo-delete" style="margin-top: 25%;" data-id="${bolo.id}">${translation["Remove Bolo"]}</Button>`}
                </div>
            </div>
        `)
    } else if (bolo.type == "vehicle") {
        el = $(`
            <div class="boloBox" style="grid-template-columns: 18% 18% 50% 13%; ${animate && `display: none;` || ""}" data-id="${bolo.id}">
                <div>
                    <p class="nameSearchResultProperty">${translation["Plate"]}:</p>
                    <p class="nameSearchResultValue" style="margin-bottom: 5%">${escapeHtml(data.plate)}</p>
                    <p class="nameSearchResultProperty">${translation["Color"]}:</p>
                    <p class="nameSearchResultValue">${escapeHtml(data.color)}</p>
                </div>
                <div>
                    <p class="nameSearchResultProperty">${translation["Make"]}:</p>
                    <p class="nameSearchResultValue" style="margin-bottom: 5%">${escapeHtml(data.make)}</p>
                    <p class="nameSearchResultProperty">${translation["Model"]}</p>
                    <p class="nameSearchResultValue">${escapeHtml(data.model)}</p>
                </div>
                <div style="margin-right: 2%">
                    ${data.info &&
                        `<p class="nameSearchResultProperty">${translation["Description"]}:</p>
                        <p class="nameSearchResultValue" style="margin-bottom: 0;">${escapeHtml(data.info)}</p>`
                    || ""}
                </div>
                <div>
                    <Button class="nameSearchResultButton bolo-delete" style="margin-top: 25%;" data-id="${bolo.id}">${translation["Remove Bolo"]}</Button>
                </div>
            </div>
        `)
    } else {
        el = $(`
            <div class="boloBox" style="grid-template-columns: 86% 13%; ${animate && `display: none;` || ""}" data-id="${bolo.id}">
                <div style="margin-right: 2%">
                    ${data.info &&
                        `<p class="nameSearchResultProperty">${translation["Description"]}:</p>
                        <p class="nameSearchResultValue" style="margin-bottom: 0">${escapeHtml(data.info)}</p>`
                    || ""}
                </div>
                <div>
                    <Button class="nameSearchResultButton bolo-delete" style="margin-top: 25%;" data-id="${bolo.id}">${translation["Remove Bolo"]}</Button>
                </div>
            </div>
        `)
    }
    e.prepend(el)
    if (animate) {el.slideToggle()}
}

// delete bolos if clicked on button and confirmed.
$(document).on("click", ".bolo-delete", async function() {
    const id = $(this).data("id");
    const result = await createConfirmScreen(translation["Are you sure you'd like to remove this bolo?"])
    if (result != "confirm") {return}
    $.post(`https://${GetParentResourceName()}/removeBolo`, JSON.stringify({
        id: id
    }));
});

$(document).on("click", ".bolo-viewCitzen", function() {
    if ($(".rightPanelNameSearch").css("display") != "block") {
        hideAllPages();
        $(".rightPanelNameSearch").fadeIn("fast");
        $("#leftPanelButtonNameSearch").css("background-color", "#3a3b3c");
    };
    
    const id = $(this).data("id");
    $("#nameLoader").fadeIn("fast");
    $("body").css("cursor", "progress")

    $.post(`https://${GetParentResourceName()}/viewRecords`, JSON.stringify({
        id: id
    }));
});

// change bolo viewing type or open bolo creator form.
$(".rightPanelBoloButtons > button").click(function() {
    const e = $(this);
    const val = e.val();
    if (val == "create") {
        const e = $(".form-bolo");
        e.fadeIn();
        e.get(-1).style.zIndex = 1000;
        document.body.append(e.get(-1));
        return;
    }
    
    bolosViewing = val
    $(".rightPanelBoloButtons > button").css("opacity", "1");
    e.css("opacity", "0.5");
    $(".rightPanelBoloResponses").empty();

    if (val == "all") {
        for (key in boloList) {
            const bolo = boloList[key]
            viewBolo(bolo)
        }
        return;
    }
    
    const bolos = allBolos[val]
    for (key in bolos) {
        const bolo = bolos[key]
        viewBolo(bolo)
    }
});

// change reports viewing type or open reports creator form.
$(".rightPanelReportsButtons > button").click(function() {
    const e = $(this);
    const val = e.val();
    if (val == "create") {
        const e = $(".form-reports");
        e.fadeIn();
        e.get(-1).style.zIndex = 1000;
        document.body.append(e.get(-1));
        return;
    }
    
    reportsViewing = val
    $(".rightPanelReportsButtons > button").css("opacity", "1");
    e.css("opacity", "0.5");
    $(".rightPanelReportsResponses").empty();


    const reports = allReports[val]
    for (key in reports) {
        const report = reports[key]
        viewReport(report)
    }
});

// Detach/attach to call button.
$(document).on("click", ".rightPanelDashboard911CallsItemRespond", function() {
    $.post(`https://${GetParentResourceName()}/unitRespondToCall`, JSON.stringify({
        id: $(this).data("call")
    }));
});

const utterance = new SpeechSynthesisUtterance();
speechSynthesis.addEventListener("voiceschanged", function() {
    const voices = speechSynthesis.getVoices();
    const desiredVoice = voices.find(voice => voice.name === "Microsoft Zira - English (United States)");
    
    utterance.voice = desiredVoice;
    utterance.rate = 1.4;    // controls the speaking rate (0.1 to 10)
    utterance.pitch = 1.2;   // controls the speaking pitch (0 to 2)
    utterance.volume = 1.0;  // controls the speaking volume (0 to 1)
});

const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
const gainNode = audioCtx.createGain();
function playBeep() {
    const oscillator = audioCtx.createOscillator();
    oscillator.type = 'triangle';
    oscillator.frequency.value = 700; // frequency in Hz
    oscillator.connect(gainNode);
    gainNode.connect(audioCtx.destination);
    gainNode.gain.setValueAtTime(0.3, audioCtx.currentTime);
    oscillator.start();

    setTimeout(function() {
        oscillator.stop();
    }, 500);
}

function orderAttachedUnits(units) {
    const attachedUnits = []
    units.forEach(unit => {
        attachedUnits[attachedUnits.length] = escapeHtml(unit)
    });
    return attachedUnits.join(",<br>")
}

const formatter = new Intl.RelativeTimeFormat("en", {
    numeric: "auto"
})

const DIVISIONS = [
    { amount: 60, name: "seconds" },
    { amount: 60, name: "minutes" },
    { amount: 24, name: "hours" },
    { amount: 7, name: "days" },
    { amount: 4.34524, name: "weeks" },
    { amount: 12, name: "months" },
    { amount: Number.POSITIVE_INFINITY, name: "years" }
]

function formatTimeAgo(date) {
    let duration = (date - new Date()) / 1000

    for (let i = 0; i <= DIVISIONS.length; i++) {
        const division = DIVISIONS[i]
        if (Math.abs(duration) < division.amount) {
            return formatter.format(Math.round(duration), division.name).replace("seconds", "sec").replace("second", "sec").replace("minutes", "min").replace("minute", "min").replace("hours", "hr").replace("hour", "hr");
        }
        duration /= division.amount
    }
}

// Event listener for nui messages.
window.addEventListener("message", function(event) {
    const item = event.data;

    // show/clsoe the ui.
    if (item.type === "display") {
        if (item.action === "open") {
            $(".background").fadeIn("fast");
            $(".topBarText").html(`<i class="fas fa-laptop"></i> ${translation["MOBILE DATA TERMINAL"]} | ${item.department} ${item.rank}`);
            $(".leftPanelPlayerInfoImage").attr("src", item.img);
            $(".leftPanelPlayerInfoUnitNumber").text(item.unitNumber || translation["Callsign not set"]);
            $(".leftPanelPlayerInfoName").text(escapeHtml(item.name));
            if (item.boss) {
                $("#leftPanelButtonEmployees").show();
            } else {
                $("#leftPanelButtonEmployees").hide();
            }
        } else if (item.action === "close") {
            $(".background").fadeOut("fast");
        };
    };

    if (item.type === "addLiveChatMessage") {
        createLiveChatMessage(item.callsign, item.dept, item.img, item.name, item.text);
    };

    // update all the units status on the dashboard.
    if (item.type === "updateUnitStatus") {
        if (item.action === "clear") {
            $(".rightPanelDashboardActiveUnits").empty();
        }
        if (item.action === "add") {
            $(".rightPanelDashboardActiveUnits").append(`
                <div class="rightPanelDashboardActiveUnitsItem">
                    <p class="rightPanelDashboardActiveUnitsItemText">${translation["Unit"]}:</p> <p class="rightPanelDashboardActiveUnitsItemTextCallsign" style="margin-bottom: 5%; margin-top: 1%;">${escapeHtml(item.unit)}</p>
                    <br>
                    <br>
                    <p class="rightPanelDashboardActiveUnitsItemText">${translation["Department"]}:</p> <p class="rightPanelDashboardActiveUnitsItemTextUnits" style="margin-bottom: 0; margin-top: 1%;">${escapeHtml(item.department)}</p>
                    <br>
                    <br>
                    <p class="rightPanelDashboardActiveUnitsItemText">${translation["Status"]}:</p> <p class="rightPanelDashboardActiveUnitsItemTextUnits" style="margin-bottom: 0; margin-top: 1%; ${item.status == translation["PANIC"] && "color: red;" || ""}">${escapeHtml(item.status)}</p>
                </div>
            `);
        }
    }

    // update all the 911 calls on the dashboard.
    if (item.type === "update911Calls") {
        $(".rightPanelDashboard911Calls").empty();
        
        JSON.parse(item.callData).forEach((call) => {
            const timeCreated = call.timeCreated*1000

            $(".rightPanelDashboard911Calls").prepend(`
                <div class="rightPanelDashboard911CallsItem">
                    <p class="CallTimeAgo911" data-timeCreated="${timeCreated}">${formatTimeAgo(currentDate.setTime(timeCreated))}</p>

                    ${call.caller && `
                        <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-phone"></i> ${translation["Caller"]}:</p> <p class="rightPanelDashboard911CallsItemTextCaller" style="margin-bottom: 8%; margin-top: 1%;">${escapeHtml(call.caller)}</p>
                        <br>
                        <br>`
                    || ""}
                    

                    ${call.location && `
                        <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-map-marker-alt"></i> ${translation["Location"]}:</p> <p class="rightPanelDashboard911CallsItemTextLocation" style="margin-bottom: 8%; margin-top: 1%;">${escapeHtml(call.location)}</p>
                        <br>
                        <br>`
                    || ""}

                    <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-comment-alt"></i> ${translation["Description"]}:</p> <p class="rightPanelDashboard911CallsItemTextDescription" style="margin-bottom: 8%; margin-top: 1%;">${escapeHtml(call.callDescription)}</p>
                    <br>
                    <br>
                    
                    ${call.attachedUnits == "none" && " " || `
                        <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-route"></i> ${translation["Responding Units"]}:</p>
                        <p class="rightPanelDashboard911CallsItemTextUnits" style="margin-top: 1%;">${orderAttachedUnits(call.attachedUnits)}</p>
                    `}

                    ${call.isAttached && `
                        <button class="rightPanelDashboard911CallsItemRespond" data-call="${call.callId}" style="background-color: rgb(201, 38, 38);">${translation["Detach from call"]} [${translation["call id"]}: ${call.callId}]</button>
                    ` || `
                        <button class="rightPanelDashboard911CallsItemRespond" data-call="${call.callId}" >${translation["Attach to call"]} [${translation["call id"]}: ${call.callId}]</button>
                    `}
                </div>
            `);
        });
    };

    // display all found citizens or show error message.
    if (item.type === "nameSearch") {
        $("#nameLoader").fadeOut("fast");
        $("body").css("cursor", "default")
        if (item.found) {
            createNameSearchResult(JSON.parse(item.data));
        } else {
            $("#searchNameDefault").text(translation["No citizen found with this name."]);
        };
    };

    // display all found weapons that match the serial number search for.
    if (item.type === "weaponSerialSearch") {
        $("#weaponLoader").fadeOut("fast");
        $("body").css("cursor", "default")
        if (item.weaponPage) {
            hideAllPages();
            $(".rightPanelWeaponSearch").fadeIn("fast");
            $("#leftPanelButtonWeaponSearch").css("background-color", "#3a3b3c");
        };
        if (item.found == true) {
            createWeaponSearchResult(JSON.parse(item.data));
        } else {
            $("#searchWeaponDefault").text(translation[item.found]);
        };
    };

    // display all found citizens vehicles or show error message.
    if (item.type === "viewVehicles") {
        $("#plateLoader").fadeOut("fast");
        $("body").css("cursor", "default");
        if (item.vehPage) {
            hideAllPages();
            $(".rightPanelPlateSearch").fadeIn("fast");
            $("#leftPanelButtonPlateSearch").css("background-color", "#3a3b3c");
        };
        if (item.found == true) {
            createVehicleSearchResult(JSON.parse(item.data));
        } else {
            $("#searchPlateDefault").text(translation[item.found]);
        };
    };

    // Show all records.
    if (item.type === "viewRecords") {
        $("#nameLoader").fadeOut("fast");
        $("body").css("cursor", "default")
        $("#nameSearch").hide();
        $(".recordsPage").fadeIn("fast");
        createRecordsPage(JSON.parse(item.data));
    };

    // show bolos.
    if (item.type === "showBolos") {
        const bolos = item.bolos
        for (key in bolos) {
            const bolo = bolos[key]
            allBolos[bolo.type][bolo.id] = bolo
            boloList[boloList.length] = bolo
            viewBolo(bolo);
        }
    }

    // show employees
    if (item.type == "viewEmployees") {
        const employees = JSON.parse(item.data)
        $("#nameLoader").fadeOut("fast");
        $("body").css("cursor", "default")
        for (key in employees) {
            const employee = employees[key]
            createEmployee(employee);
        }
    }

    // show new bolos.
    if (item.type === "newBolo") {
        const bolo = item.bolo
        allBolos[bolo.type][bolo.id] = bolo
        boloList[boloList.length] = bolo
        if (bolosViewing == bolo.type || bolosViewing == "all") {
            viewBolo(bolo, true);
        }
    }

    // remove bolos
    if (item.type === "removeBolo") {
        delete allBolos[item.boloType][item.id]
        boloList = boloList.filter((bolo) => {
            return !bolo.hasOwnProperty("id") || bolo.id !== item.id;
        });

        if (bolosViewing == item.boloType || bolosViewing == "all") {
            const e = $(".rightPanelBoloResponses").find("div").filter(`[data-id="${item.id}"]`);
            e.slideToggle()
            setTimeout(() => {
                e.remove()
            }, 500);
        }
    }

    // show reports.
    if (item.type === "showReports") {
        const reports = item.reports
        for (key in reports) {
            const report = reports[key]
            allReports[report.type][report.id] = report
            if (report.type == reportsViewing) {
                viewReport(report);
            }
        }
    }

    // show new reports.
    if (item.type === "newReport") {
        const report = item.report
        allReports[report.type][report.id] = report
        if (reportsViewing == report.type) {
            viewReport(report, true);
        }
    }

    // remove report.
    if (item.type === "removeReport") {
        delete allReports[item.reportType][item.id]
        if (reportsViewing == item.reportType || reportsViewing == "all") {
            const e = $(".rightPanelReportsResponses").find("div").filter(`[data-id="${item.id}"]`);
            e.slideToggle()
            setTimeout(() => {
                e.remove()
            }, 500);
        }
    }

    // TTS panic button and beep
    if (item.type === "panic") {
        playBeep();
        setTimeout(function() {
            playBeep();
        }, 1000);

        setTimeout(() => {            
            utterance.text = `Panic button pressed, at ${item.postal && `postal ${item.postal}, ` || ""}location ${item.location}, by unit ${item.unit}, all available units respond!`;
            speechSynthesis.speak(utterance);
        }, 1500);
    }
    
});

// Set the unit status based on the button pressed.
$(".rightPanelDashboardButtonsStatus").click(function() {
    const e = $(this)
    resetStatus()
    e.css({
        "color":"white",
        "opacity":"1"
    });
    $.post(`https://${GetParentResourceName()}/unitStatus`, JSON.stringify({
        status: e.text(),
        code: e.val()
    }));
});

// panic button click.
$("#leftPanelPanicButton").click(function() {
    resetStatus()
    $("#rightPanelDashboardPanicButton").css({
        "color":"white",
        "opacity":"1"
    });
    $.post(`https://${GetParentResourceName()}/unitStatus`, JSON.stringify({
        status: "PANIC",
        code: "10-99"
    }));
});

// switch between pages.
$("#leftPanelButtonDashboard").click(function() {
    if ($(".rightPanelDashboard").css("display") == "block") {
        return;
    };
    hideAllPages();
    $(".rightPanelDashboard").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});
$("#leftPanelButtonNameSearch").click(function() {
    if ($(".rightPanelNameSearch").css("display") == "block") {
        return;
    };
    hideAllPages();
    $(".rightPanelNameSearch").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});
$("#leftPanelButtonPlateSearch").click(function() {
    if ($(".rightPanelPlateSearch").css("display") == "block") {
        return;
    };
    hideAllPages();
    $(".rightPanelPlateSearch").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});
$("#leftPanelButtonWeaponSearch").click(function() {
    if ($(".rightPanelWeaponSearch").css("display") == "block") {
        return;
    };
    hideAllPages();
    $(".rightPanelWeaponSearch").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});

$("#leftPanelButtonBolo").click(function() {
    if ($(".rightPanelBoloPage").css("display") == "block") {
        return;
    };
    if (!bolosLoaded) {
        $.post(`https://${GetParentResourceName()}/getBolos`);
        bolosLoaded = true
    }
    hideAllPages();
    $(".rightPanelBoloPage").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});

$("#leftPanelButtonReports").click(function() {
    if ($(".rightPanelReportsPage").css("display") == "block") {
        return;
    };
    if (!reportsLoaded) {
        $.post(`https://${GetParentResourceName()}/getReports`);
        reportsLoaded = true
    }
    hideAllPages();
    $(".rightPanelReportsPage").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});
$("#leftPanelButtonLiveChat").click(function() {
    if ($(".rightPanelLiveChat").css("display") == "block") {
        return;
    };
    hideAllPages();
    $(".rightPanelLiveChat").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});
$("#leftPanelButtonEmployees").click(function() {
    if ($(".rightPanelEmployees").css("display") == "block") {
        return;
    };
    hideAllPages();
    $(".rightPanelEmployees").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");

    if ($(".rightPanelEmployeeSearchResponses").html().trim() === "") {
        $(".rightPanelEmployeeSearchResponses").show();
        $("body").css("cursor", "progress");
        $.post(`https://${GetParentResourceName()}/viewEmployees`, JSON.stringify({
            search: ""
        }));
    }
});
$("#leftPanelButtonSettings").click(function() {
    if ($(".rightPanelSettings").css("display") == "block") {
        return;
    };
    hideAllPages();
    $(".rightPanelSettings").fadeIn("fast");
    $(this).css("background-color", "#3a3b3c");
});

// close ui when - is clicked
$(".minimizeOverlay").click(function() {
    $(".background, .form-records, .form-bolo, .form-reports").fadeOut("fast");
    $.post(`https://${GetParentResourceName()}/close`);
});

// close the whole ui when the X square is clicked.
$(".closeOverlay").click(function() {
    $(".background, .form-records, .form-bolo, .form-reports").fadeOut("fast");
    $.post(`https://${GetParentResourceName()}/close`);
    setTimeout(() => {
        $(".recordsCitizen, .recordsPropertiesInfo, .recordsLicensesInfo, .rightPanelWeaponSearchResponses, .rightPanelPlateSearchResponses, .rightPanelNameSearchResponses, .rightPanelEmployeeSearchResponses").empty();
        $("#searchNameDefault").text("Search citizen by name.");
        $("#searchWeaponDefault").text("Search weapon by serial number.");
        $("#searchPlateDefault").text("Search vehicle by plate number.");
        $(".recordsPage").hide();
        $("#nameSearch").show();
        $(".background").css({
            "left": "20%",
            "top": "15%"
        });
        hideAllPages();
        $(".rightPanelDashboard").fadeIn("fast");
        $("#leftPanelButtonDashboard").css("background-color", "#3a3b3c");
        $(".form-records").css({
            "top": "30vh",
            "left": "40vw"
        })
    }, 300);
});

// Submit the name search and reset the search bar.
$("#nameSearch").submit(function() {
    const searchFirst = $("#firstNameSearchBar").val();
    const searchLast = $("#lastNameSearchBar").val();
    if ((!searchFirst || searchFirst.trim() == "") && (!searchLast || searchLast.trim() == "")) {
        return false;
    }

    $(".rightPanelNameSearchResponses").show();
    $(".rightPanelNameSearchResponses").empty();
    $("#searchNameDefault").text("");
    $("#nameLoader").fadeIn("fast");
    $("body").css("cursor", "progress")

    $.post(`https://${GetParentResourceName()}/nameSearch`, JSON.stringify({
        first: searchFirst,
        last: searchLast
    }));

    this.reset();
    return false;
});

// Submit the plate search and reset the search bar.
$("#plateSearch").submit(function() {
    const search = $("#plateSearchBar").val()
    if (!search || search.trim() == "") {
        return false;
    }

    $(".rightPanelPlateSearchResponses").show();
    $(".rightPanelPlateSearchResponses").empty();
    $("#searchPlateDefault").text("");
    $("#plateLoader").fadeIn("fast");
    $("body").css("cursor", "progress");

    $.post(`https://${GetParentResourceName()}/viewVehicles`, JSON.stringify({
        search: search,
        searchBy: "plate"
    }));

    this.reset();
    return false;
});

// Submit the employee search and reset the search bar.
$("#employeeSearch").submit(function() {
    const search = $("#employeeSearchBar").val();
    if (!search || search.trim() == "") {
        return false;
    }

    $(".rightPanelEmployeeSearchResponses").show();
    $(".rightPanelEmployeeSearchResponses").empty();
    $("#plateLoader").fadeIn("fast");
    $("body").css("cursor", "progress");

    $.post(`https://${GetParentResourceName()}/viewEmployees`, JSON.stringify({
        search: search
    }));

    this.reset();
    return false;
});


// Submit weapon serial number search and reset the search bar.
$("#weaponSearch").submit(function() {
    const search = $("#weaponSearchBar").val();
    if (!search || search.trim() == "") {
        return false;
    }

    $(".rightPanelWeaponSearchResponses").show();
    $(".rightPanelWeaponSearchResponses").empty();
    $("#searchWeaponDefault").text("");
    $("#weaponLoader").fadeIn("fast");
    $("body").css("cursor", "progress");

    $.post(`https://${GetParentResourceName()}/weaponSerialSearch`, JSON.stringify({
        search: search
    }));

    this.reset();
    return false;
});

// Submit chat and send it.
$("#liveChatForm").submit(function() {
    const liveChatMessage = $("#liveChatTextField").val()
    if (!liveChatMessage || liveChatMessage.trim() === "") {
        return false;
    }
    timeBetweenMessages.push(Date.now());
    if (timeBetweenMessages.length > 4) {
        timeBetweenMessages.shift();
        cumilativeTimeBetweenMessages = 0;
        for (index in timeBetweenMessages) {
            cumilativeTimeBetweenMessages = cumilativeTimeBetweenMessages + Date.now() - timeBetweenMessages[index];
        }
    }
    if (Math.floor(cumilativeTimeBetweenMessages / 1000) < 5) {
        $(".liveChatRateLimit").fadeIn("fast");
        setTimeout(function() {
            $(".liveChatRateLimit").fadeOut("slow");
        }, 5000);
        return false;
    }
    $.post(`https://${GetParentResourceName()}/sendLiveChat`, JSON.stringify({
        text: liveChatMessage
    }));
    this.reset();
    return false;
});

// Change tho next search bar when searching for name, when on last and ENTER is clicked then it will search.
$("#nameSearch").on("keydown", "input", function(event) {
    const $this = $(event.target);
    const index = parseFloat($this.attr("data-index"));
    switch(event.which) {
        case 13:
            if (index !== 2) {
                event.preventDefault();
                $(`[data-index="` + (index + 1).toString() + `"]`).focus();
            };
            break;
        case 8:
            if (index !== 1 && this.value.length === 0) {
                event.preventDefault();
                $(`[data-index="` + (index - 1).toString() + `"]`).focus();
            };
    };
});

// Close ui when ESC is pressed.
document.addEventListener("keydown", event => {
    if (event.key === 'Escape') {
        $(".background, .form-records, .form-bolo, .form-reports").fadeOut("fast");
        $.post(`https://${GetParentResourceName()}/close`);
    }
});

setInterval(() => {
    const elements = document.querySelectorAll(".CallTimeAgo911");
    elements.forEach(function(element) {
        const timeCreated = element.getAttribute("data-timeCreated");
        element.textContent = formatTimeAgo(currentDate.setTime(timeCreated));
    });
}, 1000);
