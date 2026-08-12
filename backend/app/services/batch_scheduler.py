"""
Models cooking several recipes at once as a scheduling problem instead of
"just do them one after another." Each recipe's own steps form a simple
chain, step 2 can't start before step 1 finishes, that's a real constraint
from the recipe itself, not something we're inventing. Different recipes
have no dependency on each other, but they compete for shared kitchen
resources (stove, oven, hands), that's the actual bottleneck this is
solving for.

Two numbers come out of this: the critical path (the longest single
recipe's total time, the best case if the kitchen had unlimited stoves and
hands) and the makespan (the real total time once resource contention is
accounted for, via a greedy list scheduler, same idea as classic job-shop
scheduling). This is a heuristic, not an optimal solver, greedy list
scheduling isn't guaranteed optimal for resource-constrained scheduling in
general, that's the honest way to describe it.
"""

import networkx as nx

from app.models.scheduling import ScheduleRequest, ScheduledStep, ScheduleResponse


def _build_graph(req: ScheduleRequest) -> nx.DiGraph:
    g = nx.DiGraph()
    for recipe in req.recipes:
        prev_node = None
        for i, step in enumerate(recipe.steps):
            node = (recipe.id, i)
            g.add_node(
                node,
                duration=step.duration_minutes,
                resource=step.resource,
                text=step.text,
                recipe_name=recipe.name,
            )
            if prev_node is not None:
                g.add_edge(prev_node, node)
            prev_node = node
    return g


def _tail_length(g: nx.DiGraph) -> dict:
    """
    Longest remaining time (in minutes) from each node to the end of its
    chain. Used as scheduling priority: whatever step has the most
    downstream work still riding on it gets scheduled first when two steps
    are both ready and want the same resource.
    """
    tail = {}
    for node in reversed(list(nx.topological_sort(g))):
        dur = g.nodes[node]["duration"]
        successors = list(g.successors(node))
        tail[node] = dur if not successors else dur + max(tail[s] for s in successors)
    return tail


def solve_schedule(req: ScheduleRequest) -> ScheduleResponse:
    g = _build_graph(req)

    if len(g.nodes) == 0:
        return ScheduleResponse(
            timeline=[], makespan_minutes=0, naive_sequential_minutes=0,
            critical_path_minutes=0, minutes_saved=0,
        )

    naive_sequential = sum(g.nodes[n]["duration"] for n in g.nodes)
    priority = _tail_length(g)
    # critical path = longest chain from any starting step to the end of
    # its recipe, in minutes. nx.dag_longest_path_length weights *edges*,
    # not nodes, and duration lives on nodes here, so that call quietly
    # returned an edge count instead of a minute total, this is the correct
    # node-weighted version, reusing the tail-length pass above
    critical_path = max((priority[n] for n in g.nodes if g.in_degree(n) == 0), default=0.0)

    in_degree = {n: g.in_degree(n) for n in g.nodes}
    # earliest a node could start, once its predecessor (if any) is done
    ready_time = {n: 0.0 for n in g.nodes if in_degree[n] == 0}

    resource_counts = req.resource_counts or {"stove": 1, "oven": 1, "hands": 1}
    # one free-at time per physical unit of a resource, e.g. 2 stove slots
    # if the kitchen has 2 burners
    resource_slots = {r: [0.0] * max(1, count) for r, count in resource_counts.items()}

    timeline = []
    in_degree_remaining = dict(in_degree)
    remaining = set(g.nodes)

    while remaining:
        ready = [n for n in remaining if in_degree_remaining[n] == 0]
        if not ready:
            break  # not reachable on a DAG, safety net against bad input
        # most downstream work left goes first, classic critical-path priority
        ready.sort(key=lambda n: priority[n], reverse=True)
        node = ready[0]

        resource = g.nodes[node]["resource"]
        slots = resource_slots.setdefault(resource, [0.0])
        slot_idx = min(range(len(slots)), key=lambda i: slots[i])

        start = max(ready_time[node], slots[slot_idx])
        duration = g.nodes[node]["duration"]
        end = start + duration
        slots[slot_idx] = end

        recipe_id, step_idx = node
        timeline.append(ScheduledStep(
            recipe_id=recipe_id,
            recipe_name=g.nodes[node]["recipe_name"],
            step_index=step_idx,
            text=g.nodes[node]["text"],
            resource=resource,
            start_minute=round(start, 1),
            end_minute=round(end, 1),
        ))

        remaining.discard(node)
        for succ in g.successors(node):
            in_degree_remaining[succ] -= 1
            if in_degree_remaining[succ] == 0:
                ready_time[succ] = end

    makespan = max((s.end_minute for s in timeline), default=0.0)

    return ScheduleResponse(
        timeline=sorted(timeline, key=lambda s: s.start_minute),
        makespan_minutes=round(makespan, 1),
        naive_sequential_minutes=round(naive_sequential, 1),
        critical_path_minutes=round(critical_path, 1),
        minutes_saved=round(naive_sequential - makespan, 1),
    )
