$(function() {

    $(".topBarText").mousedown(function(event) {
        let shiftX = event.clientX - $(".background").get(-1).getBoundingClientRect().left;
        let shiftY = event.clientY - $(".background").get(-1).getBoundingClientRect().top;
  
        $(".background").get(-1).style.position = "absolute";
        $(".background").get(-1).style.zIndex = 1000;
        document.body.append($(".background").get(-1));
  
        moveAt(event.pageX, event.pageY);
  
        function moveAt(pageX, pageY) {
            $(".background").get(-1).style.left = pageX - shiftX + "px";
            $(".background").get(-1).style.top = pageY - shiftY + "px";
        };
  
        function onMouseMove(event) {
            moveAt(event.pageX, event.pageY);
  
            $(".background").get(-1).hidden = true;
            let elemBelow = document.elementFromPoint(event.clientX, event.clientY);
            $(".background").get(-1).hidden = false;
  
            if (!elemBelow) return;
        };
  
        document.addEventListener("mousemove", onMouseMove);
  
        $(".background").get(-1).onmouseup = function(e) {
            document.removeEventListener("mousemove", onMouseMove);
            $(".background").get(-1).onmouseup = null;
        };
  
        $(".background").get(-1).ondragstart = function() {
            return false;
        };
    });

    const escapeHtml = (unsafe) => {
        return unsafe.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;');
    };

    function getBase64Image(src, callback, outputFormat) {
        const img = new Image();
        img.crossOrigin = "Anonymous";
        img.onload = () => {
            const canvas = document.createElement("canvas");
            const ctx = canvas.getContext("2d");
            let dataURL;
            canvas.height = img.naturalHeight;
            canvas.width = img.naturalWidth;
            ctx.drawImage(img, 0, 0);
            dataURL = canvas.toDataURL(outputFormat);
            callback(dataURL);
        };
        img.src = src;
        if (img.complete || img.complete === undefined) {
            img.src = "user.jpg";
            img.src = src;
        };
    };
    function Convert(pMugShotTxd, id) {
        let tempUrl = "https://nui-img/" + pMugShotTxd + "/" + pMugShotTxd + "?t=" + String(Math.round(new Date().getTime() / 1000));
        if (pMugShotTxd == "none") {
            tempUrl = "user.jpg";
        };
        getBase64Image(tempUrl, function(dataUrl) {
            $.post(`https://${GetParentResourceName()}/Answer`, JSON.stringify({
                Answer: dataUrl,
                Id: id,
            }));
        });
    };

    // Hide all pages but the dashboard on start.
    $(".rightPanelNameSearch, .rightPanelPlateSearch, .rightPanelLiveChat, .rightPanelSettings").hide();

    // This function will hide all pages and reset the background-color for the menu buttons. This is used when changing pages to display another page.
    function hideAllPages() {
        $(".rightPanelDashboard, .rightPanelNameSearch, .rightPanelPlateSearch, .rightPanelLiveChat, .rightPanelSettings").hide();
        $(".leftPanelButtons").css("background-color", "transparent");
    };

    // Reset all unit status buttons highlight on the dashboard. This is used to reset all of them then highlight another one (the active one).
    function resetStatus() {
        $(".rightPanelDashboardButtonsStatus").css({
            "color":"#ccc",
            "opacity":"0.5"
        });
    };

    function isPhoneNumber(number) {
        if (number) {
            return `<div class="nameSearchResultInfo"><p class="nameSearchResultProperty">Phone number:</p><p class="nameSearchResultValue">${escapeHtml(number)}</p></div>`;
        };
        return "";
    };

    // display character information on the name search panel.
    function createNameSearchResult(data) {
        for (const [key, value] of Object.entries(data)) {
            if (key && value) {
                $(".rightPanelNameSearchResponses").append(`
                    <div class="nameSearchResult">
                        <div class="nameSearchResultImageContainer">
                            <img class="nameSearchResultImage" src="${value.img}">
                        </div>
                        <div class="nameSearchResultInfo">
                            <p class="nameSearchResultProperty">First Name:</p>
                            <p class="nameSearchResultValue">${escapeHtml(value.firstName)}</p>
                            <p class="nameSearchResultProperty">Last Name:</p>
                            <p class="nameSearchResultValue">${escapeHtml(value.lastName)}</p>
                        </div>
                        <div class="nameSearchResultInfo">
                            <p class="nameSearchResultProperty">Date of Birth:</p>
                            <p class="nameSearchResultValue">${escapeHtml(value.dob)}</p>
                            <p class="nameSearchResultProperty">Gender:</p>
                            <p class="nameSearchResultValue">${escapeHtml(value.gender)}</p>
                        </div>
                        ${isPhoneNumber(value.phone)}
                        <div class="nameSearchResultButtons">
                            <Button id="nameSearchResultButtonRecords" data-character="${value.characterId}" class="nameSearchResultButton">View Records</Button>
                            <br>
                            <Button id="nameSearchResultButtonVehicles" data-character="${value.characterId}" class="nameSearchResultButton">View Vehicles</Button>
                        </div>
                    </div>
                `);
            };
        };
        $("#nameSearchResultButtonRecords").click(function() {
            $("#nameLoader").fadeIn("fast");
            $("body").css("cursor", "progress")
            $.post(`https://${GetParentResourceName()}/viewRecords`, JSON.stringify({
                id: $(this).data("character")
            }));
            return false;
        });
        $("#nameSearchResultButtonVehicles").click(function() {
            $("#plateLoader").fadeIn("fast");
            $("body").css("cursor", "progress")
            $.post(`https://${GetParentResourceName()}/viewVehicles`, JSON.stringify({
                search: $(this).data("character"),
                searchBy: "owner"
            }));
            return false;
        });
    };

    function vehicleText(text) {
        let txt = text
        if (txt == "NULL" || !txt) {
            txt = "Not found";
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
                        <div class="plateSearchResultGrid">
                            <div class="plateSearchResultInfo">
                                <p class="plateSearchResultProperty">Owner:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.character.firstName)} ${escapeHtml(value.character.lastName)}</p>
                                <p class="plateSearchResultProperty">Make:</p>
                                <p class="plateSearchResultValue">${escapeHtml(vehicleText(value.make))}</p>
                            </div>
                            <div class="plateSearchResultInfo">
                                <p class="plateSearchResultProperty">Plate:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.plate)}</p>
                                <p class="plateSearchResultProperty">Model:</p>
                                <p class="plateSearchResultValue">${escapeHtml(vehicleText(value.model))}</p>
                            </div>
                            <div class="plateSearchResultInfo">
                                <p class="plateSearchResultProperty">Color:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.color)}</p>
                                <p class="plateSearchResultProperty">Status:</p>
                                <p class="plateSearchResultValue">value.status</p>
                            </div>
                            <div class="plateSearchResultInfo">
                                <p class="plateSearchResultProperty">Class:</p>
                                <p class="plateSearchResultValue">${escapeHtml(value.class)}</p>
                            </div>
                        </div>
                        <Button id="plateSearchResultButton" data-first="${value.character.firstName}" data-last="${value.character.lastName}" class="plateSearchResultButton">Search citizen</Button>
                    </div>
                `);
            };
        };
        $("#plateSearchResultButton").click(function() {
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
    }

    function recordsCheckPhone(number) {
        if (!number) {
            return "";
        };
        return `<p class="recordsCitizenProperty">Phone number:</p><p class="recordsCitizenValue">${escapeHtml(number)}</p>`
    };

    // Creates a records page for a citizen with options to give citation and all that.
    function createRecordsPage(data) {
        $(".recordsReturn").click(function() {
            $(".recordsPage").hide();
            $("#nameSearch").show();
        });

        $(".recordsCitizen, .recordsPropertiesInfo").empty();

        if (!data || !data.citizen) {
            return;
        };

        $(".recordsCitizen").append(`
            <div class="recordsCitizenImageContainer">
                <img class="recordsCitizenImage" src="${data.citizen.img || "user.jpg"}">
            </div>
            <div class="recordsCitizenInfo">
                <p class="recordsCitizenProperty">First name:</p>
                <p class="recordsCitizenValue">${escapeHtml(data.citizen.firstName)}</p>
                <p class="recordsCitizenProperty">Last name:</p>
                <p class="recordsCitizenValue">${escapeHtml(data.citizen.lastName)}</p>
                ${recordsCheckPhone(data.citizen.phone)}
            </div>
            <div class="recordsCitizenInfo">
                <p class="recordsCitizenProperty">Date of Birth:</p>
                <p class="recordsCitizenValue">${escapeHtml(data.citizen.dob)}</p>
                <p class="recordsCitizenProperty">Gender:</p>
                <p class="recordsCitizenValue">${escapeHtml(data.citizen.gender)}</p>
            </div>
            <div class="recordsCitizenNotes">
                <p class="recordsCitizenNotesTitle">Notes:</p>
                <textarea id="recordsCitizenNotesText" data-character="${data.citizen.characterId}"></textarea>
            </div>
        `);
        
        if (data.records.notes) {
            $("#recordsCitizenNotesText").val(escapeHtml(data.records.notes));
        };

        if (data.properties) {
            for (let i = 0; i < data.properties.length; i++) {
                $(".recordsPropertiesInfo").prepend(`
                    <div class="recordsPropertiesItem">
                        <p class="recordsPropertoesAddress">${data.properties[i]}</p>
                    </div>
                `);
            };
        };

    };

    $(".recordsCitizenSave").click(function() {
        $.post(`https://${GetParentResourceName()}/saveRecords`, JSON.stringify({
            character: $("#recordsCitizenNotesText").data("character"),
            notes: $("#recordsCitizenNotesText").val()
        }));
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

    // Event listener for nui messages.
    window.addEventListener("message", function(event) {
        const item = event.data;

        if (item.type == "convert") {
            Convert(item.pMugShotTxd, item.id);
        }

        // show/clsoe the ui.
        if (item.type === "display") {
            if (item.action === "open") {
                $(".background").fadeIn("fast");
                if (!item.unitNumber) {
                    $(".overlay").hide();
                    $("setUnitNumberFirstTime").show();
                }
                $(".topBarText").html(`<i class="fas fa-laptop"></i> MOBILE DATA TERMINAL | ${item.department}`);
                $(".leftPanelPlayerInfoImage").attr("src", item.img);
                $(".leftPanelPlayerInfoUnitNumber").text(item.unitNumber);
                $(".leftPanelPlayerInfoName").text(escapeHtml(item.name));
            } else if (item.action === "close") {
                $(".background").fadeOut("fast");
            };
        };

        if (item.type === "addLiveChatMessage") {
            createLiveChatMessage(item.callsign, item.dept, item.img, item.name, item.text);
        };

        if (item.type === "updateUnitNumber") {

        };

        // update all the units status on the dashboard.
        if (item.type === "updateUnitStatus") {
            if (item.action === "clear") {
                $(".rightPanelDashboardActiveUnits").empty();
            }
            if (item.action === "add") {
                $(".rightPanelDashboardActiveUnits").append(`
                    <div class="rightPanelDashboardActiveUnitsItem">
                        <p class="rightPanelDashboardActiveUnitsItemText"><i class="fas fa-id-badge"></i> Unit:</p>
                        <p class="rightPanelDashboardActiveUnitsItemTextCallsign" style="margin-bottom: 5%; margin-top: 1%;">${escapeHtml(item.unit)}</p>
                        <p class="rightPanelDashboardActiveUnitsItemText"><i class="fas fa-exclamation-circle"></i> Status:</p>
                        <p class="rightPanelDashboardActiveUnitsItemTextUnits" style="margin-bottom: 0; margin-top: 1%;">${item.status}</p>
                    </div>
                `);
            }
        }

        // update all the 911 calls on the dashboard.
        if (item.type === "update911Calls") {
            $(".rightPanelDashboard911Calls").empty();
            JSON.parse(item.callData).forEach((call) => {
                if (call.isAttached) {
                    $(".rightPanelDashboard911Calls").prepend(`
                        <div class="rightPanelDashboard911CallsItem">
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-phone"></i> Caller:</p>
                            <p class="rightPanelDashboard911CallsItemTextCaller" style="margin-bottom: 8%; margin-top: 1%;">${escapeHtml(call.caller)}</p>
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-map-marker-alt"></i> Location:</p>
                            <p class="rightPanelDashboard911CallsItemTextLocation" style="margin-bottom: 8%; margin-top: 1%;">${call.location}</p>
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-comment-alt"></i> Description:</p>
                            <p class="rightPanelDashboard911CallsItemTextDescription" style="margin-bottom: 8%; margin-top: 1%;">${escapeHtml(call.callDescription)}</p>
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-route"></i> Responding Units:</p>
                            <p class="rightPanelDashboard911CallsItemTextUnits" style="margin-top: 1%;">${escapeHtml(call.attachedUnits)}</p>
                            <button class="rightPanelDashboard911CallsItemRespond" data-call="${call.callId}" style="background-color: rgb(201, 38, 38);">Detach from call [call id: ${call.callId}]</button>
                        </div>
                    `);
                } else {
                    $(".rightPanelDashboard911Calls").prepend(`
                        <div class="rightPanelDashboard911CallsItem">
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-phone"></i> Caller:</p>
                            <p class="rightPanelDashboard911CallsItemTextCaller" style="margin-bottom: 8%; margin-top: 1%;">${escapeHtml(call.caller)}</p>
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-map-marker-alt"></i> Location:</p>
                            <p class="rightPanelDashboard911CallsItemTextLocation" style="margin-bottom: 8%; margin-top: 1%;">${call.location}</p>
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-comment-alt"></i> Description:</p>
                            <p class="rightPanelDashboard911CallsItemTextDescription" style="margin-bottom: 8%; margin-top: 1%;">${escapeHtml(call.callDescription)}</p>
                            <p class="rightPanelDashboard911CallsItemText"><i class="fas fa-route"></i> Responding Units:</p>
                            <p class="rightPanelDashboard911CallsItemTextUnits" style="margin-top: 1%;">${escapeHtml(call.attachedUnits)}</p>
                            <button class="rightPanelDashboard911CallsItemRespond" data-call="${call.callId}" >Attach to call [call id: ${call.callId}]</button>
                        </div>
                    `);
                }
            });
            
            // Detach/attach to call button.
            $(".rightPanelDashboard911CallsItemRespond").click(function() {
                $.post(`https://${GetParentResourceName()}/unitRespondToCall`, JSON.stringify({
                    id: $(this).data("call")
                }));
            });
        };

        // display all found citizens or show error message.
        if (item.type === "nameSearch") {
            $("#nameLoader").fadeOut("fast");
            $("body").css("cursor", "default")
            if (item.found) {
                createNameSearchResult(JSON.parse(item.data));
            } else {
                $("#searchNameDefault").text("No citizen found with this name.");
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
                $("#searchPlateDefault").text(item.found);
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
    });

    // Set the unit status based on the button pressed.
    $(".rightPanelDashboardButtonsStatus").click(function() {
        resetStatus()
        $(this).css({
            "color":"white",
            "opacity":"1"
        });
        $.post(`https://${GetParentResourceName()}/unitStatus`, JSON.stringify({
            status: $(this).text()
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
    $("#leftPanelButtonLiveChat").click(function() {
        if ($(".rightPanelLiveChat").css("display") == "block") {
            return;
        };
        hideAllPages();
        $(".rightPanelLiveChat").fadeIn("fast");
        $(this).css("background-color", "#3a3b3c");
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
        $(".background").fadeOut("fast");
        $.post(`https://${GetParentResourceName()}/close`);
    });

    // close the whole ui when the X square is clicked.
    $(".closeOverlay").click(function() {
        $(".background").fadeOut("fast");
        $.post(`https://${GetParentResourceName()}/close`);
        setTimeout(() => {
            $(".recordsCitizen, .recordsPropertiesInfo, .recordsLicensesInfo, .rightPanelWeaponSearchResponses, .rightPanelPlateSearchResponses, .rightPanelNameSearchResponses").empty();
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
        }, 300);
    });

    // Submit the name search and reset the search bar.
    $("#nameSearch").submit(function() {
        $(".rightPanelNameSearchResponses").show();
        $(".rightPanelNameSearchResponses").empty();
        $("#searchNameDefault").text("");
        $("#nameLoader").fadeIn("fast");
        $("body").css("cursor", "progress")
        $.post(`https://${GetParentResourceName()}/nameSearch`, JSON.stringify({
            first: $("#firstNameSearchBar").val(),
            last: $("#lastNameSearchBar").val()
        }));
        this.reset();
        return false;
    });

    // Submit the plate search and reset the search bar.
    $("#plateSearch").submit(function() {
        $(".rightPanelPlateSearchResponses").show();
        $(".rightPanelPlateSearchResponses").empty();
        $("#searchPlateDefault").text("");
        $("#plateLoader").fadeIn("fast");
        $("body").css("cursor", "progress");
        $.post(`https://${GetParentResourceName()}/viewVehicles`, JSON.stringify({
            search: $("#plateSearchBar").val(),
            searchBy: "plate"
        }));
        this.reset();
        return false;
    });

    // Submit chat and send it.
    let timeBetweenMessages = [];
    let cumilativeTimeBetweenMessages;
    $("#liveChatForm").submit(function() {
        const liveChatMessage = $("#liveChatTextField").val()
        if (liveChatMessage.trim() === "" || liveChatMessage === null) {
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

    // Set the unit number for the user and show the main page.
    $("#setUnitNumber").submit(function() {
        $.post(`https://${GetParentResourceName()}/setUnitNumber`, JSON.stringify({
            number: $("#setUnitNumberFirstTimeInput").val()
        }));
        $(".overlay").show();
        $("setUnitNumberFirstTime").hide();
        return false;
    });

    // Close ui when ESC is pressed.
    document.onkeyup = function(data) { 
        if (data.which == 27) {
            $(".background").fadeOut("fast");
            $.post(`https://${GetParentResourceName()}/close`);
            return;
        };
    };
});