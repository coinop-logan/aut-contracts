//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../../../daoUtils/interfaces/get/IDAOInteractions.sol";
import "../../../../../daoUtils/interfaces/get/IDAOAdmin.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../../../../interfaces/modules/quest/QuestsModule.sol";
import "../../SimplePlugin.sol";
import "../../../../interfaces/modules/tasks/TasksModule.sol";
import "../../../../interfaces/registry/IPluginRegistry.sol";
import "hardhat/console.sol";

contract QuestPlugin is QuestsModule, SimplePlugin {
    using Counters for Counters.Counter;

    Counters.Counter private idCounter;

    QuestModel[] quests;
    address public onboardingPlugin;

    uint256 constant SECONDS_IN_DAY = 86400;
    mapping(uint256 => PluginTasks[]) questTasks;
    mapping(uint256 => uint[]) public taskToQuests;
    mapping(uint256 => address[]) questCompletions;
    mapping(uint256 => uint256) public activeQuestsPerRole;

    constructor(address dao) SimplePlugin(dao) {
        idCounter.increment();
        onboardingPlugin = msg.sender;
        quests.push(QuestModel(0, false, "", 0, block.timestamp, 0, 0));
    }

    modifier onlyAdmin() {
        require(IDAOAdmin(daoAddress()).isAdmin(msg.sender), "Not an admin.");
        _;
    }

    modifier onlyOngoing(uint256 questId) {
        require(isOngoing(questId), "Only ongoing");
        _;
    }

    modifier onlyPending(uint256 questId) {
        require(isPending(questId), "Only pending");
        _;
    }

    modifier onlyActive(uint256 questId) {
        require(quests[questId].active, "Only active quest");
        _;
    }

    function create(
        uint256 _role,
        string memory _uri,
        uint256 _maxAmountOfCompletions,
        uint256 _durationInDays
    ) public override onlyAdmin returns (uint256) {
        require(bytes(_uri).length > 0, "No URI");
        uint256 questId = idCounter.current();

        quests.push(
            QuestModel(
                _role,
                false,
                _uri,
                _durationInDays,
                block.timestamp,
                0,
                _maxAmountOfCompletions
            )
        );

        if (activeQuestsPerRole[_role] == 0)
            activeQuestsPerRole[_role] = questId;

        idCounter.increment();
        emit QuestCreated(questId);
        return questId;
    }

    function createTask(
        uint256 questId,
        uint256 tasksPluginId,
        string memory uri
    ) public onlyAdmin onlyPending(questId) {
        IPluginRegistry.PluginInstance memory pluginInstance = pluginRegistry
            .getPluginInstanceByTokenId(tasksPluginId);
        uint256 taskId = TasksModule(pluginInstance.pluginAddress).createBy(
            msg.sender,
            quests[questId].role,
            uri,
            quests[questId].startDate,
            quests[questId].startDate +
                quests[questId].durationInDays *
                SECONDS_IN_DAY
        );
        _addTask(questId, PluginTasks(tasksPluginId, taskId));
        emit TasksAddedToQuest(questId, taskId);
    }

    function markAsFinalized(address user, uint questId)
        public
        override
        onlyDAOModule
        onlyActive(questId)
        onlyOngoing(questId)
    {
        require(idCounter.current() >= questId, "invalid quest id");
        if (hasCompletedAQuest(user, questId)) {
            questCompletions[questId].push(user);
            emit QuestCompleted(questId, user);
        }
    }

    function removeTasks(uint256 questId, PluginTasks[] calldata tasksToRemove)
        public
        override
        onlyAdmin
        onlyPending(questId)
    {
        require(idCounter.current() >= questId, "invalid quest id");

        for (uint256 i = 0; i < tasksToRemove.length; i++) {
            _removeTask(questId, tasksToRemove[i]);
        }

        emit TasksRemovedFromQuest();
    }

    function editQuest(
        uint256 questId,
        uint256 _role,
        string memory _uri,
        uint256 _durationInDays
    ) public override onlyAdmin onlyPending(questId) {
        require(idCounter.current() >= questId, "invalid quest id");
        require(_role > 0, "invalid _role");
        require(bytes(_uri).length > 0, "invalid _uri");
        require(_durationInDays > 0, "invalid _durationInDays");

        quests[questId].metadataUri = _uri;
        quests[questId].durationInDays = _durationInDays;
        quests[questId].role = _role;

        emit QuestEditted();
    }

    function isOngoing(uint256 questId) public view override returns (bool) {
        return
            quests[questId].startDate +
                quests[questId].durationInDays *
                SECONDS_IN_DAY <
            block.timestamp &&
            quests[questId].startDate > block.timestamp;
    }

    function isPending(uint256 questId) public view override returns (bool) {
        return quests[questId].startDate < block.timestamp;
    }

    function getById(uint256 questId)
        public
        view
        override
        returns (QuestModel memory)
    {
        return quests[questId];
    }

    function getTasksPerQuest(uint256 questId)
        public
        view
        returns (PluginTasks[] memory)
    {
        return questTasks[questId];
    }

    function hasCompletedAQuest(address user, uint256 questId)
        public
        view
        override
        returns (bool)
    {
        return getTimeOfCompletion(user, questId) > 0;
    }

    function getTimeOfCompletion(address user, uint256 questId)
        public
        view
        override
        returns (uint256)
    {
        if (questTasks[questId].length == 0) return 0;
        uint256 lastTaskTime = 0;
        for (uint256 i = 0; i < questTasks[questId].length; i++) {
            address tasksAddress = IPluginRegistry(pluginRegistry)
                .getPluginInstanceByTokenId(questTasks[questId][i].pluginId)
                .pluginAddress;
            console.log(
                "questTasks[questId][i].taskId",
                questTasks[questId][i].taskId
            );
            if (
                TasksModule(tasksAddress).hasCompletedTheTask(
                    user,
                    questTasks[questId][i].taskId
                )
            ) {
                uint256 completionTime = TasksModule(tasksAddress)
                    .getCompletionTime(questTasks[questId][i].taskId, user);

                if (completionTime > lastTaskTime)
                    lastTaskTime = completionTime;
            }
        }
        return lastTaskTime;
    }

    function hasCompletedQuestForRole(address user, uint256 role)
        public
        view
        override
        returns (bool)
    {
        uint256 questId = activeQuestsPerRole[role];
        if (questId == 0) return false;
        return hasCompletedAQuest(user, questId);
    }

    // private

    function findTask(uint256 questId, PluginTasks memory task)
        private
        view
        returns (int256)
    {
        for (uint256 i = 0; i < questTasks[questId].length; i++) {
            if (
                questTasks[questId][i].pluginId == task.pluginId &&
                questTasks[questId][i].taskId == task.taskId
            ) {
                return int256(i);
            }
        }
        return -1;
    }

    function getQuestsOfATask(uint taskId) public override view returns(uint[] memory) {
        return taskToQuests[taskId];
    }

    function _addTask(uint256 questId, PluginTasks memory task) private {
        require(idCounter.current() >= questId, "invalid quest id");
        IPluginRegistry.PluginInstance memory plugin = IPluginRegistry(
            pluginRegistry
        ).getPluginInstanceByTokenId(task.pluginId);

        require(plugin.pluginAddress != address(0), "Invalid plugin");
        bool isInstalled = IPluginRegistry(pluginRegistry)
            .pluginDefinitionsInstalledByDAO(
                daoAddress(),
                plugin.pluginDefinitionId
            );
        if (
            TasksModule(plugin.pluginAddress).daoAddress() == daoAddress() &&
            isInstalled
        ) {
            int256 index = findTask(questId, task);
            if (index == -1) {
                questTasks[questId].push(task);
                quests[questId].tasksCount++;
                emit TasksAddedToQuest(questId, task.taskId);
            }
        }
    }

    function _removeTask(uint256 questId, PluginTasks calldata taskToRemove)
        public
    {
        int256 index = findTask(questId, taskToRemove);
        require(index != -1, "invalid task");
        questTasks[questId][uint256(index)].taskId = 0;
        questTasks[questId][uint256(index)].pluginId = 0;
        quests[questId].tasksCount--;
    }
}