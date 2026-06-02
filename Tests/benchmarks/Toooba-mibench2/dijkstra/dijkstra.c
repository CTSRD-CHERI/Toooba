#include <util.h>
#include "../bareBench.h"
#include "input.h"

#define NUM_NODES                          100
#define NONE                               9999

struct _NODE
{
  int iDist;
  int iPrev;
};
typedef struct _NODE NODE;

struct _QITEM
{
  int iNode;
  int iDist;
  int iPrev;
  struct _QITEM *qNext;
};
typedef struct _QITEM QITEM;

/*
 * Dijkstra's algorithm calculates the shortest path between two nodes
 * by calculating the shortest path from 1 node to all the other nodes.
 * At the Nth step, the algorithm "visits" the closest node to
 * any of the N already visited nodes.
 * Then, the algorithm checks the (NUM_NODES - N) unvisited nodes and
 * adds a node to the queue if a shorter path to that node is found.
 * Thus, the maximum number of nodes that could be added to the queue is
 * NUM_NODES + (NUM_NODES - 1) + ... + 2 + 1 ~= (NUM_NODES * NUM_NODES / 2)
 */
#define ARRAY_SIZE (NUM_NODES * NUM_NODES / 2)
QITEM allocated[ARRAY_SIZE];
QITEM *qHead = NULL;
int notAll = 0;

int g_qCount = 0;
NODE rgnNodes[NUM_NODES];
int ch;
int iPrev, iNode;
int i, iCost, iDist;


void print_path (NODE *rgnNodes, int chNode)
{
  if (rgnNodes[chNode].iPrev != NONE)
    {
      print_path(rgnNodes, rgnNodes[chNode].iPrev);
    }
  //printf (" %d", chNode);
  fflush(stdout);
}

void enqueue (int iNode, int iDist, int iPrev)
{
  QITEM *qNew = &allocated[notAll];
  notAll++;
  QITEM *qLast = qHead;
  
  if (notAll >= ARRAY_SIZE) 
    {
      //printf("Out of memory.\n");
      exit(1);
    }
  qNew->iNode = iNode;
  qNew->iDist = iDist;
  qNew->iPrev = iPrev;
  qNew->qNext = NULL;
  
  if (!qLast) 
    {
      qHead = qNew;
    }
  else
    {
      qLast = &allocated[notAll-2];
      qLast->qNext = qNew;
    }
  g_qCount++;
  //               ASSERT(g_qCount);
}


void dequeue (int *piNode, int *piDist, int *piPrev)
{
  QITEM *qKill = qHead;
  
  if (qHead)
    {
      //                 ASSERT(g_qCount);
      *piNode = qHead->iNode;
      *piDist = qHead->iDist;
      *piPrev = qHead->iPrev;
      qHead = qHead->qNext;
      //free(qKill);
      g_qCount--;
    }
}


int qcount (void)
{
  return(g_qCount);
}

int dijkstra(int chStart, int chEnd) 
{
  notAll = 0;

  for (ch = 0; ch < NUM_NODES; ch++)
    {
      rgnNodes[ch].iDist = NONE;
      rgnNodes[ch].iPrev = NONE;
    }
  if (chStart == chEnd) 
    {
      //printf("Shortest path is 0 in cost. Just stay where you are.\n");
    }
  else
    {
      rgnNodes[chStart].iDist = 0;
      rgnNodes[chStart].iPrev = NONE;
      enqueue (chStart, 0, NONE);

     while (qcount() > 0)
	{
	  dequeue (&iNode, &iDist, &iPrev);
	  for (i = 0; i < NUM_NODES; i++)
	    {
	      if ((iCost = AdjMatrix[iNode][i]) != NONE)
		{
		  if ((NONE == rgnNodes[i].iDist) || 
		      (rgnNodes[i].iDist > (iCost + iDist)))
		    {
		      rgnNodes[i].iDist = iDist + iCost;
		      rgnNodes[i].iPrev = iNode;
		      enqueue (i, iDist + iCost, iNode);
		    }
		}
	    }
	}
      
      //printf("Shortest path is %d in cost. ", rgnNodes[chEnd].iDist);
      //printf("Path is: ");
      //print_path(rgnNodes, chEnd);
      //printf("\n");
    }
    return 0;
}

int main(int argc, char *argv[]) {
  int i,j;
   /* make a fully connected matrix */
   // see input.h
  /* finds 2 shortest paths between nodes */
  /* otherwise, too long for simulation */
  for (i=1;i<3;i++) {
			int x=i*31%NUM_NODES;
      int y=i*13%NUM_NODES;
      dijkstra(x,y);
  }
  return 0;
}
