# proofs of laws/ToolsListGivesTable.bend
import Base
import ../src/server.bend as Server
import ../laws/ToolsListGivesTable.bend as Laws
import ./lemmas/ArrayItemsRoundTrip.bend as M1

def Laws.list_dispatch(_srv, _params):
  {==}

def Laws.list_items(_name, _version, _instructions, tools):
  M1.eq.items_arr(Server.tool.all(tools))

def Laws.list_each(_t, _rest):
  {==}

def Laws.tool_fields(_name, _description, _input):
  {==}

def Laws.list_one_page(srv):
  match srv:
    case Server.Server{name, version, instructions, tools}:
      {==}
